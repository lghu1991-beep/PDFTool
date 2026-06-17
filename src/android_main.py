# -*- coding: utf-8 -*-
"""PDFTool - Android 版（Flet UI）。"""

from __future__ import annotations

import os
import shutil
import sys
import tempfile
import traceback
from typing import Callable, List, Optional

import flet as ft

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

_IMPORT_ERROR: Optional[BaseException] = None
try:
    from pdf_core import (  # noqa: E402
        add_image_watermark,
        add_text_watermark,
        compress_pdf,
        format_size,
        merge_pdfs,
        pdf_page_count,
        split_every_page,
        split_pdf,
    )
except Exception as exc:  # noqa: BLE001
    _IMPORT_ERROR = exc


def _app_storage_root() -> str:
    root = os.environ.get("FLET_APP_STORAGE_DATA")
    if root:
        return root
    return tempfile.gettempdir()


def _app_output_dir() -> str:
    out = os.path.join(_app_storage_root(), "output")
    os.makedirs(out, exist_ok=True)
    return out


def _app_input_dir() -> str:
    inp = os.path.join(_app_storage_root(), "input")
    os.makedirs(inp, exist_ok=True)
    return inp


def _stem(path: str) -> str:
    return os.path.splitext(os.path.basename(path))[0]


def _default_output(input_path: str, suffix: str) -> str:
    return os.path.join(_app_output_dir(), "%s%s.pdf" % (_stem(input_path), suffix))


def _resolve_picked_path(picked: ft.FilePickerFile) -> str:
    src = (picked.path or "").strip()
    if src and os.path.isfile(src):
        return src
    name = (picked.name or "").strip()
    if not name:
        return ""
    if src:
        return src
    return os.path.join(_app_input_dir(), name)


def _stage_picked_file(picked: ft.FilePickerFile) -> str:
    """将系统选择器返回的文件复制到应用可读写目录。"""
    src = _resolve_picked_path(picked)
    if not src:
        return ""
    if not os.path.isfile(src):
        return src
    name = os.path.basename(picked.name or src)
    dst = os.path.join(_app_input_dir(), name)
    if os.path.abspath(src) != os.path.abspath(dst):
        shutil.copy2(src, dst)
    return dst


class PdfToolPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.page.title = "PDFTool"
        self.page.theme_mode = ft.ThemeMode.LIGHT
        self.page.bgcolor = ft.Colors.WHITE
        self.page.scroll = ft.ScrollMode.AUTO
        self.page.padding = 16

        self.status = ft.Text("就绪", color="#666666")
        self.busy = ft.ProgressBar(visible=False)

        self.file_picker = ft.FilePicker(on_result=self._on_file_picked)
        self.page.overlay.append(self.file_picker)

        self._pick_callback: Optional[Callable[[List[str]], None]] = None

        self.tabs = ft.Tabs(
            selected_index=0,
            animation_duration=200,
            scrollable=True,
            tabs=[
                ft.Tab(text="水印", content=self._build_watermark_tab()),
                ft.Tab(text="压缩", content=self._build_compress_tab()),
                ft.Tab(text="合并", content=self._build_merge_tab()),
                ft.Tab(text="拆分", content=self._build_split_tab()),
            ],
            expand=True,
        )

        self.page.add(
            ft.Column(
                [
                    ft.Text("PDFTool - PDF 工具", size=22, weight=ft.FontWeight.BOLD),
                    ft.Text(
                        "Android 版支持水印、压缩、合并、拆分。输出文件默认保存在应用目录 output 下。",
                        size=12,
                        color="#666666",
                    ),
                    ft.Container(content=self.tabs, expand=True),
                    self.busy,
                    self.status,
                ],
                expand=True,
                spacing=12,
            )
        )
        self.page.update()

    def _scroll_tab(self, *controls: ft.Control) -> ft.Container:
        return ft.Container(
            content=ft.Column(list(controls), spacing=12, scroll=ft.ScrollMode.AUTO),
            padding=8,
            expand=True,
        )

    def _path_field(self, label: str, value: str = "") -> ft.TextField:
        return ft.TextField(
            label=label,
            value=value,
            read_only=True,
            multiline=True,
            min_lines=1,
            max_lines=3,
        )

    def _pick_button(self, text: str, on_click) -> ft.OutlinedButton:
        return ft.OutlinedButton(text=text, icon=ft.Icons.FOLDER_OPEN, on_click=on_click)

    def _build_watermark_tab(self) -> ft.Container:
        self.wm_input = self._path_field("PDF 文件")
        self.wm_output = self._path_field("输出 PDF")
        self.wm_mode = ft.RadioGroup(
            value="text",
            content=ft.Column(
                [
                    ft.Radio(value="text", label="文字水印"),
                    ft.Radio(value="image", label="图片水印"),
                ],
                spacing=4,
            ),
        )
        self.wm_text = ft.TextField(label="水印文字", value="机密")
        self.wm_opacity = ft.Slider(min=0.05, max=0.9, value=0.25, divisions=17, label="{value}")
        self.wm_angle = ft.TextField(label="角度", value="45", keyboard_type=ft.KeyboardType.NUMBER)
        self.wm_font = ft.TextField(label="字号", value="48", keyboard_type=ft.KeyboardType.NUMBER)
        self.wm_image = self._path_field("水印图片")
        self.wm_scale = ft.Slider(min=0.08, max=0.8, value=0.25, divisions=18, label="{value}")
        self.wm_position = ft.Dropdown(
            label="位置",
            value="center",
            options=[
                ft.dropdown.Option("center", "居中"),
                ft.dropdown.Option("top-left", "左上"),
                ft.dropdown.Option("top-right", "右上"),
                ft.dropdown.Option("bottom-left", "左下"),
                ft.dropdown.Option("bottom-right", "右下"),
            ],
        )
        self.wm_img_angle = ft.TextField(label="图片角度", value="0", keyboard_type=ft.KeyboardType.NUMBER)

        self.wm_text_panel = ft.Column([self.wm_text, self.wm_angle, self.wm_font], spacing=8)
        self.wm_image_panel = ft.Column(
            [
                self.wm_image,
                self._pick_button("选择水印图片", lambda _: self._pick_images(self._set_wm_image)),
                self.wm_scale,
                self.wm_position,
                self.wm_img_angle,
            ],
            spacing=8,
            visible=False,
        )

        def on_mode_change(_):
            is_image = self.wm_mode.value == "image"
            self.wm_text_panel.visible = not is_image
            self.wm_image_panel.visible = is_image
            self.page.update()

        self.wm_mode.on_change = on_mode_change

        return self._scroll_tab(
            self.wm_input,
            self._pick_button(
                "选择 PDF",
                lambda _: self._pick_pdfs(
                    allow_multiple=False,
                    on_picked=lambda paths: self._set_input_output(
                        self.wm_input, self.wm_output, paths[0], "_watermark"
                    ),
                ),
            ),
            self.wm_output,
            self.wm_mode,
            self.wm_text_panel,
            self.wm_image_panel,
            ft.Text("透明度"),
            self.wm_opacity,
            ft.FilledButton("添加水印", icon=ft.Icons.BRANDING_WATERMARK, on_click=self._run_watermark),
        )

    def _build_compress_tab(self) -> ft.Container:
        self.compress_input = self._path_field("PDF 文件")
        self.compress_output = self._path_field("输出 PDF")
        self.compress_level = ft.RadioGroup(
            value="medium",
            content=ft.Column(
                [
                    ft.Radio(value="light", label="轻（流压缩）"),
                    ft.Radio(value="medium", label="中（推荐，流压缩 + 去重）"),
                    ft.Radio(value="strong", label="强（无 PyMuPDF 时回退到中档）"),
                ],
                spacing=4,
            ),
        )
        return self._scroll_tab(
            ft.Text("Android 不含 Ghostscript / PyMuPDF，强压缩将自动回退为内置压缩。", size=12),
            self.compress_input,
            self._pick_button(
                "选择 PDF",
                lambda _: self._pick_pdfs(
                    allow_multiple=False,
                    on_picked=lambda paths: self._set_input_output(
                        self.compress_input, self.compress_output, paths[0], "_compressed"
                    ),
                ),
            ),
            self.compress_output,
            self.compress_level,
            ft.FilledButton("开始压缩", icon=ft.Icons.COMPRESS, on_click=self._run_compress),
        )

    def _build_merge_tab(self) -> ft.Container:
        self.merge_list = ft.Column(spacing=4)
        self.merge_paths: List[str] = []
        self.merge_output = self._path_field("输出 PDF")
        return self._scroll_tab(
            ft.Text("按顺序合并多个 PDF："),
            ft.Container(
                content=self.merge_list,
                border=ft.border.all(1, "#dddddd"),
                border_radius=8,
                padding=8,
                height=160,
            ),
            ft.Row(
                [
                    self._pick_button("添加 PDF", lambda _: self._pick_pdfs(allow_multiple=True, on_picked=self._merge_add_paths)),
                    ft.OutlinedButton("清空", icon=ft.Icons.CLEAR_ALL, on_click=self._merge_clear),
                ],
                wrap=True,
                spacing=8,
            ),
            self.merge_output,
            ft.FilledButton("合并", icon=ft.Icons.MERGE_TYPE, on_click=self._run_merge),
        )

    def _build_split_tab(self) -> ft.Container:
        self.split_input = self._path_field("PDF 文件")
        self.split_output_dir = self._path_field("输出目录")
        self.split_mode = ft.RadioGroup(
            value="range",
            content=ft.Column(
                [
                    ft.Radio(value="range", label="按页码范围（如 1-3,5-8）"),
                    ft.Radio(value="each", label="每页单独一个 PDF"),
                ],
                spacing=4,
            ),
        )
        self.split_range = ft.TextField(label="页码范围", value="1-1", keyboard_type=ft.KeyboardType.NUMBER)
        return self._scroll_tab(
            self.split_input,
            self._pick_button(
                "选择 PDF",
                lambda _: self._pick_pdfs(
                    allow_multiple=False,
                    on_picked=lambda paths: self._set_split_input(paths[0]),
                ),
            ),
            self.split_mode,
            self.split_range,
            self.split_output_dir,
            ft.FilledButton("拆分", icon=ft.Icons.CONTENT_CUT, on_click=self._run_split),
        )

    def _set_input_output(
        self,
        input_field: ft.TextField,
        output_field: ft.TextField,
        input_path: str,
        suffix: str,
    ) -> None:
        input_field.value = input_path
        output_field.value = _default_output(input_path, suffix)
        self.page.update()

    def _set_wm_image(self, paths: List[str]) -> None:
        if paths:
            self.wm_image.value = paths[0]
            self.page.update()

    def _set_split_input(self, input_path: str) -> None:
        self.split_input.value = input_path
        self.split_output_dir.value = os.path.join(_app_output_dir(), _stem(input_path) + "_split")
        self.page.update()

    def _pick_pdfs(self, allow_multiple: bool, on_picked: Callable[[List[str]], None]) -> None:
        self._pick_callback = on_picked
        self.file_picker.pick_files(
            dialog_title="选择 PDF",
            file_type=ft.FilePickerFileType.CUSTOM,
            allowed_extensions=["pdf"],
            allow_multiple=allow_multiple,
        )

    def _pick_images(self, on_picked: Callable[[List[str]], None]) -> None:
        self._pick_callback = on_picked
        self.file_picker.pick_files(
            dialog_title="选择图片",
            file_type=ft.FilePickerFileType.IMAGE,
            allow_multiple=False,
        )

    def _merge_add_paths(self, paths: List[str]) -> None:
        for path in paths:
            if path not in self.merge_paths:
                self.merge_paths.append(path)
                self.merge_list.controls.append(ft.Text(os.path.basename(path)))
        if self.merge_paths and not self.merge_output.value:
            self.merge_output.value = os.path.join(
                _app_output_dir(), "merged_%d.pdf" % len(self.merge_paths)
            )
        self.page.update()

    def _on_file_picked(self, e: ft.FilePickerResultEvent) -> None:
        if not self._pick_callback:
            return
        if not e.files:
            self._pick_callback = None
            self.status.value = "未选择文件"
            self.page.update()
            return
        paths: List[str] = []
        for item in e.files:
            staged = _stage_picked_file(item)
            if staged:
                paths.append(staged)
        if not paths:
            self._pick_callback = None
            self._show_dialog("选择文件失败", "无法读取所选文件，请重试或更换文件。")
            return
        self._pick_callback(paths)
        self._pick_callback = None
        self.status.value = "已选择 %d 个文件" % len(paths)
        self.page.update()

    def _merge_clear(self, _=None) -> None:
        self.merge_paths.clear()
        self.merge_list.controls.clear()
        self.page.update()

    def _set_busy(self, busy: bool, message: str) -> None:
        self.busy.visible = busy
        self.status.value = message
        self.page.update()

    def _run_async(self, title: str, fn: Callable[[], object]) -> None:
        self._set_busy(True, "%s 处理中…" % title)

        def worker() -> tuple:
            try:
                return ("ok", fn())
            except Exception as exc:
                return ("err", exc)

        def done(payload: tuple) -> None:
            kind, value = payload
            if kind == "ok":
                self._on_success(title, value)
            else:
                self._on_error(title, value)

        self.page.run_thread(worker, done)

    def _show_dialog(self, title: str, message: str) -> None:
        def close_dialog(_=None) -> None:
            self.page.close(dlg)

        dlg = ft.AlertDialog(
            title=ft.Text(title),
            content=ft.Text(message),
            actions=[ft.TextButton("确定", on_click=close_dialog)],
        )
        self.page.open(dlg)

    def _on_success(self, title: str, result: object) -> None:
        self._set_busy(False, "%s 完成" % title)
        if isinstance(result, dict) and "before" in result:
            self._show_dialog(
                title,
                "方式：%s\n原始：%s\n压缩后：%s\n节省：%s（%.1f%%）\n\n%s"
                % (
                    result.get("method_label", "内置"),
                    format_size(result["before"]),
                    format_size(result["after"]),
                    format_size(result["saved"]),
                    result["ratio"],
                    result["path"],
                ),
            )
        elif isinstance(result, list):
            self._show_dialog(
                title,
                "共 %d 个文件\n\n%s" % (len(result), "\n".join(result[:5])),
            )
        else:
            self._show_dialog(title, str(result))

    def _on_error(self, title: str, exc: Exception) -> None:
        self._set_busy(False, "%s 失败" % title)
        self._show_dialog("错误", str(exc))

    def _ensure_parent(self, path: str) -> None:
        parent = os.path.dirname(os.path.abspath(path))
        if parent:
            os.makedirs(parent, exist_ok=True)

    def _run_watermark(self, _) -> None:
        src = (self.wm_input.value or "").strip()
        dst = (self.wm_output.value or "").strip()
        if not src or not dst:
            self._on_error("添加水印", ValueError("请选择 PDF 文件"))
            return

        def job():
            self._ensure_parent(dst)
            opacity = float(self.wm_opacity.value or 0.25)
            if self.wm_mode.value == "image":
                image_path = (self.wm_image.value or "").strip()
                if not image_path:
                    raise ValueError("请选择水印图片")
                add_image_watermark(
                    src,
                    dst,
                    image_path,
                    opacity=opacity,
                    scale=float(self.wm_scale.value or 0.25),
                    angle=float(self.wm_img_angle.value or 0),
                    position=self.wm_position.value,  # type: ignore[arg-type]
                )
            else:
                add_text_watermark(
                    src,
                    dst,
                    self.wm_text.value or "",
                    opacity=opacity,
                    angle=float(self.wm_angle.value or 45),
                    font_size=int(float(self.wm_font.value or 48)),
                )
            return dst

        self._run_async("添加水印", job)

    def _run_compress(self, _) -> None:
        src = (self.compress_input.value or "").strip()
        dst = (self.compress_output.value or "").strip()
        if not src or not dst:
            self._on_error("PDF 压缩", ValueError("请选择 PDF 文件"))
            return

        def job():
            self._ensure_parent(dst)
            return compress_pdf(src, dst, level=self.compress_level.value)  # type: ignore[arg-type]

        self._run_async("PDF 压缩", job)

    def _run_merge(self, _) -> None:
        dst = (self.merge_output.value or "").strip()
        if len(self.merge_paths) < 2:
            self._on_error("合并 PDF", ValueError("请至少添加 2 个 PDF"))
            return
        if not dst:
            self._on_error("合并 PDF", ValueError("输出路径无效"))
            return

        def job():
            self._ensure_parent(dst)
            merge_pdfs(self.merge_paths, dst)
            return dst

        self._run_async("合并 PDF", job)

    def _parse_ranges(self, text: str) -> List[tuple]:
        ranges: List[tuple] = []
        for part in text.split(","):
            part = part.strip()
            if not part:
                continue
            if "-" in part:
                a, b = part.split("-", 1)
                start, end = int(a.strip()), int(b.strip())
            else:
                start = end = int(part)
            ranges.append((start, end))
        return ranges

    def _run_split(self, _) -> None:
        src = (self.split_input.value or "").strip()
        out_dir = (self.split_output_dir.value or "").strip()
        if not src or not out_dir:
            self._on_error("拆分 PDF", ValueError("请选择 PDF 文件"))
            return

        def job():
            os.makedirs(out_dir, exist_ok=True)
            if self.split_mode.value == "each":
                return split_every_page(src, out_dir)
            ranges = self._parse_ranges(self.split_range.value or "1-1")
            return split_pdf(src, out_dir, ranges)

        self._run_async("拆分 PDF", job)


def _show_startup_error(page: ft.Page, title: str, detail: str) -> None:
    page.title = "PDFTool"
    page.theme_mode = ft.ThemeMode.LIGHT
    page.bgcolor = ft.Colors.WHITE
    page.padding = 16
    page.add(
        ft.Text(title, size=20, weight=ft.FontWeight.BOLD, color=ft.Colors.RED_700),
        ft.Text(
            "请重新安装 universal 包，或用 adb logcat 查看详细日志。",
            size=12,
            color="#666666",
        ),
        ft.Text(detail, size=12, selectable=True),
    )
    page.update()


def main(page: ft.Page) -> None:
    if _IMPORT_ERROR is not None:
        _show_startup_error(
            page,
            "PDF 模块加载失败",
            "".join(traceback.format_exception_only(type(_IMPORT_ERROR), _IMPORT_ERROR)),
        )
        return
    try:
        PdfToolPage(page)
    except Exception as exc:  # noqa: BLE001
        _show_startup_error(page, "界面初始化失败", traceback.format_exc())


def _run_app() -> None:
    if hasattr(ft, "run"):
        ft.run(main)
    else:
        ft.app(target=main)


if __name__ == "__main__":
    _run_app()
