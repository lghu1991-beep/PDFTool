# -*- coding: utf-8 -*-
"""PDF 核心能力：水印、合并、拆分、压缩。"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from io import BytesIO
from typing import Iterable, List, Literal, Optional, Tuple

from PIL import Image
from pypdf import PdfReader, PdfWriter
from reportlab.lib.colors import Color
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfgen import canvas

WatermarkPosition = Literal[
    "center",
    "top-left",
    "top-center",
    "top-right",
    "left-center",
    "right-center",
    "bottom-left",
    "bottom-center",
    "bottom-right",
]
WatermarkLayout = Literal["single", "grid", "tile"]
CompressLevel = Literal["light", "medium", "strong"]


def _ensure_parent_dir(output_path: str) -> None:
    parent = os.path.dirname(os.path.abspath(output_path))
    if parent:
        os.makedirs(parent, exist_ok=True)


def merge_pdfs(input_paths: Iterable[str], output_path: str) -> None:
    writer = PdfWriter()
    for path in input_paths:
        reader = PdfReader(path)
        for page in reader.pages:
            writer.add_page(page)
    os.makedirs(os.path.dirname(os.path.abspath(output_path)) or ".", exist_ok=True)
    with open(output_path, "wb") as f:
        writer.write(f)


def split_pdf(input_path: str, output_dir: str, page_ranges: List[Tuple[int, int]]) -> List[str]:
    """按页码区间拆分，页码从 1 开始，闭区间 [start, end]。"""
    reader = PdfReader(input_path)
    total = len(reader.pages)
    os.makedirs(output_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(input_path))[0]
    outputs: List[str] = []

    for idx, (start, end) in enumerate(page_ranges, start=1):
        if start < 1 or end > total or start > end:
            raise ValueError("页码范围无效：%d-%d（共 %d 页）" % (start, end, total))
        writer = PdfWriter()
        for page_num in range(start - 1, end):
            writer.add_page(reader.pages[page_num])
        out_path = os.path.join(output_dir, "%s_%d-%d.pdf" % (base, start, end))
        with open(out_path, "wb") as f:
            writer.write(f)
        outputs.append(out_path)
    return outputs


def split_every_page(input_path: str, output_dir: str) -> List[str]:
    reader = PdfReader(input_path)
    os.makedirs(output_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(input_path))[0]
    outputs: List[str] = []
    for i, page in enumerate(reader.pages, start=1):
        writer = PdfWriter()
        writer.add_page(page)
        out_path = os.path.join(output_dir, "%s_p%d.pdf" % (base, i))
        with open(out_path, "wb") as f:
            writer.write(f)
        outputs.append(out_path)
    return outputs


def _build_text_overlay(
    width: float,
    height: float,
    text: str,
    opacity: float,
    angle: float,
    font_size: int,
    position: WatermarkPosition,
    layout: WatermarkLayout,
) -> bytes:
    # Render watermark on an in-memory single-page PDF, then merge into each target page.
    font_name = _pick_text_font(text)
    text_width = max(24.0, pdfmetrics.stringWidth(text, font_name, font_size))
    text_height = max(16.0, font_size * 1.2)
    packet = BytesIO()
    c = canvas.Canvas(packet, pagesize=(width, height))
    for x, y in _layout_points(width, height, text_width, text_height, position, layout):
        c.saveState()
        c.setFillColor(Color(0, 0, 0, alpha=opacity))
        c.setFont(font_name, font_size)
        cx, cy = x + text_width / 2.0, y + text_height / 2.0
        c.translate(cx, cy)
        c.rotate(angle)
        c.drawCentredString(0, -font_size * 0.35, text)
        c.restoreState()
    c.save()
    return packet.getvalue()


def _position_xy(
    position: WatermarkPosition,
    page_w: float,
    page_h: float,
    img_w: float,
    img_h: float,
    margin: float = 24.0,
) -> Tuple[float, float]:
    if position == "center":
        return (page_w - img_w) / 2.0, (page_h - img_h) / 2.0
    if position == "top-left":
        return margin, page_h - img_h - margin
    if position == "top-center":
        return (page_w - img_w) / 2.0, page_h - img_h - margin
    if position == "top-right":
        return page_w - img_w - margin, page_h - img_h - margin
    if position == "left-center":
        return margin, (page_h - img_h) / 2.0
    if position == "right-center":
        return page_w - img_w - margin, (page_h - img_h) / 2.0
    if position == "bottom-left":
        return margin, margin
    if position == "bottom-center":
        return (page_w - img_w) / 2.0, margin
    return page_w - img_w - margin, margin


def _layout_points(
    page_w: float,
    page_h: float,
    obj_w: float,
    obj_h: float,
    position: WatermarkPosition,
    layout: WatermarkLayout,
) -> List[Tuple[float, float]]:
    if layout == "single":
        return [_position_xy(position, page_w, page_h, obj_w, obj_h)]
    if layout == "grid":
        xs = [24.0, (page_w - obj_w) / 2.0, max(24.0, page_w - obj_w - 24.0)]
        ys = [24.0, (page_h - obj_h) / 2.0, max(24.0, page_h - obj_h - 24.0)]
        return [(x, y) for y in ys for x in xs]

    step_x = max(obj_w * 1.8, 120.0)
    step_y = max(obj_h * 2.2, 90.0)
    points: List[Tuple[float, float]] = []
    y = 24.0
    row = 0
    while y <= page_h - obj_h:
        x = 24.0 + (step_x * 0.4 if row % 2 else 0.0)
        while x <= page_w - obj_w:
            points.append((x, y))
            x += step_x
        y += step_y
        row += 1
    return points or [_position_xy(position, page_w, page_h, obj_w, obj_h)]


def _pick_text_font(text: str) -> str:
    # CJK text needs CID font; Helvetica cannot render Chinese.
    if any(ord(ch) > 127 for ch in text):
        font_name = "STSong-Light"
        if font_name not in pdfmetrics.getRegisteredFontNames():
            pdfmetrics.registerFont(UnicodeCIDFont(font_name))
        return font_name
    return "Helvetica-Bold"


def _load_rgba_image(image_path: str, opacity: float) -> Image.Image:
    if not os.path.isfile(image_path):
        raise FileNotFoundError("找不到图片：%s" % image_path)
    img = Image.open(image_path).convert("RGBA")
    alpha = max(0.05, min(float(opacity), 1.0))
    r, g, b, a = img.split()
    a = a.point(lambda p: int(p * alpha))
    return Image.merge("RGBA", (r, g, b, a))


def _build_image_overlay(
    page_w: float,
    page_h: float,
    image_path: str,
    opacity: float,
    scale: float,
    angle: float,
    position: WatermarkPosition,
    layout: WatermarkLayout,
) -> bytes:
    img = _load_rgba_image(image_path, opacity)
    img_w, img_h = img.size
    target_w = max(32.0, page_w * max(0.05, min(float(scale), 1.0)))
    ratio = target_w / float(img_w)
    target_h = img_h * ratio
    # Resize to final draw size first, so PDF does not embed oversized source bitmap.
    draw_w = max(1, int(round(target_w)))
    draw_h = max(1, int(round(target_h)))
    draw_img = img.resize((draw_w, draw_h), Image.LANCZOS)
    draw_reader = ImageReader(draw_img)
    packet = BytesIO()
    c = canvas.Canvas(packet, pagesize=(page_w, page_h))
    for x, y in _layout_points(page_w, page_h, target_w, target_h, position, layout):
        c.saveState()
        if abs(angle) > 0.01:
            cx, cy = x + target_w / 2.0, y + target_h / 2.0
            c.translate(cx, cy)
            c.rotate(angle)
            c.drawImage(
                draw_reader,
                -target_w / 2.0,
                -target_h / 2.0,
                width=target_w,
                height=target_h,
                mask="auto",
            )
        else:
            c.drawImage(draw_reader, x, y, width=target_w, height=target_h, mask="auto")
        c.restoreState()
    c.save()
    return packet.getvalue()


def _apply_overlay_pages(input_path: str, output_path: str, overlay_builder) -> None:
    # Core watermark pipeline:
    # 1) build per-page overlay PDF in memory
    # 2) merge overlay into original page content
    # 3) write merged result directly (no implicit auto-compress here)
    reader = PdfReader(input_path)
    writer = PdfWriter()
    for page in reader.pages:
        width = float(page.mediabox.width)
        height = float(page.mediabox.height)
        overlay_bytes = overlay_builder(width, height)
        overlay_page = PdfReader(BytesIO(overlay_bytes)).pages[0]
        page.merge_page(overlay_page)
        writer.add_page(page)
    _ensure_parent_dir(output_path)
    with open(output_path, "wb") as f:
        writer.write(f)


def add_text_watermark(
    input_path: str,
    output_path: str,
    text: str,
    opacity: float = 0.25,
    angle: float = 45.0,
    font_size: int = 48,
    position: WatermarkPosition = "center",
    layout: WatermarkLayout = "single",
) -> None:
    if not text.strip():
        raise ValueError("水印文字不能为空")
    alpha = max(0.05, min(float(opacity), 1.0))

    def builder(width: float, height: float) -> bytes:
        return _build_text_overlay(width, height, text, alpha, angle, font_size, position, layout)

    _apply_overlay_pages(input_path, output_path, builder)


def add_image_watermark(
    input_path: str,
    output_path: str,
    image_path: str,
    opacity: float = 0.35,
    scale: float = 0.25,
    angle: float = 0.0,
    position: WatermarkPosition = "center",
    layout: WatermarkLayout = "single",
) -> None:
    def builder(width: float, height: float) -> bytes:
        return _build_image_overlay(width, height, image_path, opacity, scale, angle, position, layout)

    _apply_overlay_pages(input_path, output_path, builder)


def _find_ghostscript() -> Optional[str]:
    candidates: List[str] = []
    if sys.platform == "win32":
        gs_root = os.environ.get("GS_HOME", r"C:\Program Files\gs")
        if os.path.isdir(gs_root):
            for name in sorted(os.listdir(gs_root), reverse=True):
                for exe_name in ("gswin64c.exe", "gswin32c.exe"):
                    exe = os.path.join(gs_root, name, "bin", exe_name)
                    if os.path.isfile(exe):
                        candidates.append(exe)
        for exe_name in ("gswin64c", "gswin32c"):
            found = shutil.which(exe_name)
            if found:
                candidates.insert(0, found)
    else:
        for path in ("/opt/homebrew/bin/gs", "/usr/local/bin/gs", "/usr/bin/gs"):
            if os.path.isfile(path):
                candidates.append(path)
        found = shutil.which("gs")
        if found:
            candidates.insert(0, found)

    seen = set()
    for path in candidates:
        if path not in seen and os.path.isfile(path):
            seen.add(path)
            return path
    return None


def _compress_with_pypdf(input_path: str, output_path: str, aggressive: bool) -> None:
    reader = PdfReader(input_path)
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    for page in writer.pages:
        try:
            page.compress_content_streams()
        except ValueError:
            pass
    if aggressive:
        writer.compress_identical_objects()
    _ensure_parent_dir(output_path)
    with open(output_path, "wb") as f:
        writer.write(f)


def _compress_with_pymupdf(
    input_path: str,
    output_path: str,
    dpi_threshold: int = 150,
    dpi_target: int = 72,
    image_quality: int = 50,
) -> None:
    try:
        import fitz
    except ImportError as exc:
        raise RuntimeError("强压缩需要 pymupdf，请执行：pip install pymupdf") from exc

    # PyInstaller onefile：确保 MuPDF 原生 DLL 可被加载（Win10 常见启动问题）
    if getattr(sys, "frozen", False) and hasattr(os, "add_dll_directory"):
        meipass = getattr(sys, "_MEIPASS", "")
        if meipass and os.path.isdir(meipass):
            try:
                os.add_dll_directory(meipass)
            except OSError:
                pass

    _ensure_parent_dir(output_path)
    doc = fitz.open(input_path)
    try:
        doc.rewrite_images(
            dpi_threshold=dpi_threshold,
            dpi_target=dpi_target,
            quality=image_quality,
            lossy=True,
            lossless=True,
            bitonal=True,
            color=True,
            gray=True,
        )
        doc.save(
            output_path,
            garbage=4,
            deflate=True,
            clean=True,
            pretty=False,
        )
    finally:
        doc.close()


def _compress_with_ghostscript(input_path: str, output_path: str, profile: str) -> None:
    gs = _find_ghostscript()
    if not gs:
        raise RuntimeError("未找到 Ghostscript")
    _ensure_parent_dir(output_path)
    cmd = [
        gs,
        "-sDEVICE=pdfwrite",
        "-dCompatibilityLevel=1.4",
        "-dPDFSETTINGS=%s" % profile,
        "-dDetectDuplicateImages=true",
        "-dCompressFonts=true",
        "-dSubsetFonts=true",
        "-dNOPAUSE",
        "-dQUIET",
        "-dBATCH",
        "-sOutputFile=%s" % output_path,
        input_path,
    ]
    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=300,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )
    if proc.returncode != 0 or not os.path.isfile(output_path):
        raise RuntimeError("Ghostscript 压缩失败：\n%s" % (proc.stderr or proc.stdout))


def compress_pdf(
    input_path: str,
    output_path: str,
    level: CompressLevel = "medium",
) -> dict:
    """压缩 PDF，返回原始/输出大小（字节）。"""
    if not os.path.isfile(input_path):
        raise FileNotFoundError("找不到文件：%s" % input_path)

    before = os.path.getsize(input_path)
    method = "pypdf"
    if level == "light":
        _compress_with_pypdf(input_path, output_path, aggressive=False)
    elif level == "medium":
        _compress_with_pypdf(input_path, output_path, aggressive=True)
    else:
        gs = _find_ghostscript()
        if gs:
            try:
                _compress_with_ghostscript(input_path, output_path, "/screen")
                method = "ghostscript"
            except RuntimeError:
                try:
                    _compress_with_pymupdf(input_path, output_path)
                    method = "pymupdf"
                except (ImportError, RuntimeError):
                    _compress_with_pypdf(input_path, output_path, aggressive=True)
                    method = "pypdf"
        else:
            try:
                _compress_with_pymupdf(input_path, output_path)
                method = "pymupdf"
            except (ImportError, RuntimeError):
                _compress_with_pypdf(input_path, output_path, aggressive=True)
                method = "pypdf"

    after = os.path.getsize(output_path)
    saved = max(0, before - after)
    ratio = (saved / before * 100.0) if before > 0 else 0.0
    method_label = {
        "pypdf": "内置流压缩",
        "pymupdf": "图片重采样（72dpi）",
        "ghostscript": "Ghostscript /screen",
    }.get(method, method)
    return {
        "before": before,
        "after": after,
        "saved": saved,
        "ratio": ratio,
        "path": output_path,
        "method": method,
        "method_label": method_label,
    }


def format_size(num_bytes: int) -> str:
    if num_bytes >= 1024 * 1024:
        return "%.2f MB" % (num_bytes / (1024 * 1024))
    if num_bytes >= 1024:
        return "%.1f KB" % (num_bytes / 1024)
    return "%d B" % num_bytes


def pdf_page_count(input_path: str) -> int:
    return len(PdfReader(input_path).pages)
