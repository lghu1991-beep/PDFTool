# -*- coding: utf-8 -*-
"""Word / Office 文档转 PDF（Windows）。"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from typing import List, Optional


OFFICE_EXTS = {".doc", ".docx", ".wps", ".rtf", ".odt", ".xls", ".xlsx", ".ppt", ".pptx"}


def _libreoffice_paths() -> List[str]:
    if sys.platform != "win32":
        return []
    candidates = [
        r"C:\Program Files\LibreOffice\program\soffice.exe",
        r"C:\Program Files (x86)\LibreOffice\program\soffice.exe",
        r"C:\Program Files\LibreOffice\program\soffice.com",
    ]
    env_path = os.environ.get("LIBREOFFICE_PATH", "").strip()
    if env_path:
        candidates.insert(0, env_path)
    return [p for p in candidates if os.path.isfile(p)]


def _find_soffice() -> Optional[str]:
    for path in _libreoffice_paths():
        return path
    found = shutil.which("soffice")
    return found


def word_to_pdf(input_path: str, output_path: Optional[str] = None) -> str:
    input_path = os.path.abspath(input_path)
    if not os.path.isfile(input_path):
        raise FileNotFoundError("找不到文件：%s" % input_path)

    ext = os.path.splitext(input_path)[1].lower()
    if ext not in OFFICE_EXTS:
        raise ValueError("不支持的格式：%s" % ext)

    if output_path is None:
        output_path = os.path.splitext(input_path)[0] + ".pdf"
    output_path = os.path.abspath(output_path)
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    soffice = _find_soffice()
    if soffice:
        return _convert_with_libreoffice(soffice, input_path, output_path)

    if sys.platform == "win32":
        try:
            return _convert_with_word_com(input_path, output_path)
        except Exception as exc:
            raise RuntimeError(
                "未检测到 LibreOffice，且 Microsoft Word 转换失败。\n"
                "请安装 LibreOffice（推荐）或 Microsoft Word。\n"
                "LibreOffice 下载：https://www.libreoffice.org/download/\n"
                "详情：%s" % exc
            ) from exc

    raise RuntimeError(
        "当前系统无法转换 Word。\n"
        "请在 Windows 上运行，并安装 LibreOffice 或 Microsoft Word。"
    )


def _convert_with_libreoffice(soffice: str, input_path: str, output_path: str) -> str:
    out_dir = os.path.dirname(output_path) or "."
    with tempfile.TemporaryDirectory() as tmp:
        cmd = [
            soffice,
            "--headless",
            "--norestore",
            "--convert-to",
            "pdf",
            "--outdir",
            tmp,
            input_path,
        ]
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=180,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        if proc.returncode != 0:
            raise RuntimeError(
                "LibreOffice 转换失败（code=%s）：\n%s"
                % (proc.returncode, proc.stderr or proc.stdout)
            )

        base = os.path.splitext(os.path.basename(input_path))[0] + ".pdf"
        generated = os.path.join(tmp, base)
        if not os.path.isfile(generated):
            pdfs = [f for f in os.listdir(tmp) if f.lower().endswith(".pdf")]
            if not pdfs:
                raise RuntimeError("LibreOffice 未生成 PDF 文件")
            generated = os.path.join(tmp, pdfs[0])

        if os.path.abspath(generated) != os.path.abspath(output_path):
            shutil.move(generated, output_path)
    return output_path


def _convert_with_word_com(input_path: str, output_path: str) -> str:
    """需要本机安装 Microsoft Word（仅 doc/docx/rtf）。"""
    ext = os.path.splitext(input_path)[1].lower()
    if ext not in {".doc", ".docx", ".rtf"}:
        raise RuntimeError("Word COM 仅支持 .doc / .docx / .rtf，请安装 LibreOffice 处理其他格式")

    try:
        import win32com.client  # type: ignore
    except ImportError as exc:
        raise RuntimeError("请安装 pywin32：pip install pywin32") from exc

    input_path = os.path.abspath(input_path)
    output_path = os.path.abspath(output_path)
    word = win32com.client.Dispatch("Word.Application")
    word.Visible = False
    doc = None
    try:
        doc = word.Documents.Open(input_path, ReadOnly=True)
        doc.SaveAs(output_path, FileFormat=17)
        return output_path
    finally:
        if doc is not None:
            doc.Close(False)
        word.Quit()
