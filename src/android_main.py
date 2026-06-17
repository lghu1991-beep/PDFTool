# -*- coding: utf-8 -*-
"""PDFTool - Android 版（Flet UI）。"""

from __future__ import annotations

import os
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


def _app_output_dir() -> str:
    root = os.environ.get("FLET_APP_STORAGE_DATA")
    if root:
        out = os.path.join(root, "output")
    else:
        out = os.path.join(tempfile.gettempdir(), "pdftool")
    os.makedirs(out, exist_ok=True)
    return out


def _stem(path: str) -> str:
    return os.path.splitext(os.path.basename(path))[0]


def _default_output(input_path: str, suffix: str) -> str:
    return os.path.join(_app_output_dir(), "%s%s.pdf" % (_stem(input_path), suffix))


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
        self.save_picker = ft.FilePicker(on_result=self._on_save_picked)
        self.page.overlay.extend([self.file_picker, self.save_picker])

        self._pick_callback: Optional[Callable[[str], None]] = None
        self._save_callback: Optional[Callable[[str], None]] = None

        self.tabs = ft.Tabs(
            selected_index=0,
            animation_duration=200,
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
                        "Android 版支持水印、压缩、合并、拆分。Word 转 PDF 请使用 Windows 桌面版。",
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

    def _build_watermark_tab(self) -> ft.Container:
        self.wm_input = ft.TextField(label="PDF 文件", read_only=True, expand=True)
        self.wm_output = ft.TextField(label="输出 PDF", read_only=True, expand=True)
        self.wm_mode = ft.RadioGroup(
            value="text",
            content=ft.Row(
                [
                    ft.Radio(value="text", label="文字水印"),
                    ft.Radio(value="image", label="图片水印"),
                ]
            ),
        )
        self.wm_text = ft.TextField(label="水印文字", value="机密")
        self.wm_opacity = ft.Slider(min=0.05, max=0.9, value=0.25, divisions=17, label="{value}")
        self.wm_angle = ft.TextField(label="角度", value="45", width=100)
        self.wm_font = ft.TextField(label="字号", value="48", width=100)
        self.wm_image = ft.TextField(label="水印图片", read_only=True, expand=True)
        self.wm_scale = ft.Slider(min=0.08, max=0.8, value=0.25, divisions=18, label="{value}")
        self.wm_position = ft.Dropdown(
            label="位置",
            value="center",
            options=[
                ft.dropdown.Option("center"),
                ft.dropdown.Option("top-left"),
                ft.dropdown.Option("top-right"),
                ft.dropdown.Option("bottom-left"),
                ft.dropdown.Option("bottom-right"),
            ],
            width=180,
        )
        self.wm_img_angle = ft.TextField(label="图片角度", value="0", width=100)

        self.wm_text_panel = ft.Column([self.wm_text, ft.Row([self.wm_angle, self.wm_font])])
        self.wm_image_panel = ft.Column(
            [
                ft.Row(
                    [
                        self.wm_image,
                        ft.IconButton(
                            icon=ft.Icons.IMAGE,
                            tooltip="选择图片",
                            on_click=lambda _: self._pick_file(
                                [ft.FilePickerFileType.IMAGE],
                                lambda p: self.wm_image.__setattr__("value", p) or self.page.update(),
                            ),
                        ),
                    ]
                ),
                self.wm_scale,
                ft.Row([self.wm_position, self.wm_img_angle]),
            ],
            visible=False,
        )

        def on_mode_change(_):
            is_image = self.wm_mode.value == "image"
            self.wm_text_panel.visible = not is_image
            self.wm_image_panel.visible = is_image
            self.page.update()

        self.wm_mode.on_change = on_mode_change

        return ft.Container(
            content=ft.Column(
                [
                    ft.Row(
                        [
                            self.wm_input,
                            ft.IconButton(
                                icon=ft.Icons.FOLDER_OPEN,
                                on_click=lambda _: self._pick_pdf(
                                    self.wm_input,
                                    lambda p: self.wm_output.__setattr__(
                                        "value", _default_output(p, "_watermark")
                                    ),
                                ),
                            ),
                        ]
                    ),
                    ft.Row(
                        [
                            self.wm_output,
                            ft.IconButton(
                                icon=ft.Icons.SAVE,
                                on_click=lambda _: self._pick_save(self.wm_output, ".pdf"),
                            ),
                        ]
                    ),
                    self.wm_mode,
                    self.wm_text_panel,
                    self.wm_image_panel,
                    ft.Text("透明度"),
                    self.wm_opacity,
                    ft.FilledButton("添加水印", on_click=self._run_watermark),
                ],
                spacing=10,
            ),
            padding=8,
        )

    def _build_compress_tab(self) -> ft.Container:
        self.compress_input = ft.TextField(label="PDF 文件", read_only=True, expand=True)
        self.compress_output = ft.TextField(label="输出 PDF", read_only=True, expand=True)
        self.compress_level = ft.RadioGroup(
            value="medium",
            content=ft.Column(
                [
                    ft.Radio(value="light", label="轻（流压缩）"),
                    ft.Radio(value="medium", label="中（推荐，流压缩 + 去重）"),
                    ft.Radio(value="strong", label="强（无 PyMuPDF 时回退到中档）"),
                ]
            ),
        )
        return ft.Container(
            content=ft.Column(
                [
                    ft.Text("Android 不含 Ghostscript / PyMuPDF，强压缩将自动回退为内置压缩。", size=12),
                    ft.Row(
                        [
                            self.compress_input,
                            ft.IconButton(
                                icon=ft.Icons.FOLDER_OPEN,
                                on_click=lambda _: self._pick_pdf(
                                    self.compress_input,
                                    lambda p: self.compress_output.__setattr__(
                                        "value", _default_output(p, "_compressed")
                                    ),
                                ),
                            ),
                        ]
                    ),
                    ft.Row(
                        [
                            self.compress_output,
                            ft.IconButton(
                                icon=ft.Icons.SAVE,
                                on_click=lambda _: self._pick_save(self.compress_output, ".pdf"),
                            ),
                        ]
                    ),
                    self.compress_level,
                    ft.FilledButton("开始压缩", on_click=self._run_compress),
                ],
                spacing=10,
            ),
            padding=8,
        )

    def _build_merge_tab(self) -> ft.Container:
        self.merge_list = ft.ListView(expand=True, height=180, spacing=4)
        self.merge_paths: List[str] = []
        self.merge_output = ft.TextField(label="输出 PDF", read_only=True, expand=True)
        return ft.Container(
            content=ft.Column(
                [
                    ft.Text("按顺序合并多个 PDF："),
                    self.merge_list,
                    ft.Row(
                        [
                            ft.OutlinedButton(
                                "添加 PDF",
                                icon=ft.Icons.ADD,
                                on_click=lambda _: self._pick_files_merge(),
                            ),
                            ft.OutlinedButton(
                                "清空",
                                icon=ft.Icons.CLEAR_ALL,
                                on_click=self._merge_clear,
                            ),
                        ]
                    ),
                    ft.Row(
                        [
                            self.merge_output,
                            ft.IconButton(
                                icon=ft.Icons.SAVE,
                                on_click=lambda _: self._pick_save(self.merge_output, ".pdf"),
                            ),
                        ]
                    ),
                    ft.FilledButton("合并", on_click=self._run_merge),
                ],
                spacing=10,
            ),
            padding=8,
        )

    def _build_split_tab(self) -> ft.Container:
        self.split_input = ft.TextField(label="PDF 文件", read_only=True, expand=True)
        self.split_output_dir = ft.TextField(label="输出目录", read_only=True, expand=True)
        self.split_mode = ft.RadioGroup(
            value="range",
            content=ft.Column(
                [
                    ft.Radio(value="range", label="按页码范围（如 1-3,5-8）"),
                    ft.Radio(value="each", label="每页单独一个 PDF"),
                ]
            ),
        )
        self.split_range = ft.TextField(label="页码范围", value="1-1")
        return ft.Container(
            content=ft.Column(
                [
                    ft.Row(
                        [
                            self.split_input,
                            ft.IconButton(
                                icon=ft.Icons.FOLDER_OPEN,
                                on_click=lambda _: self._pick_pdf(
                                    self.split_input,
                                    lambda p: self.split_output_dir.__setattr__(
                                        "value", os.path.join(_app_output_dir(), _stem(p) + "_split")
                                    ),
                                ),
                            ),
                        ]
                    ),
                    self.split_mode,
                    self.split_range,
                    self.split_output_dir,
                    ft.FilledButton("拆分", on_click=self._run_split),
                ],
                spacing=10,
            ),
            padding=8,
        )

    def _pick_pdf(self, field: ft.TextField, on_picked: Optional[Callable[[str], None]] = None) -> None:
        self._pick_callback = lambda path: self._set_field(field, path, on_picked)
        self.file_picker.pick_files(allowed_extensions=["pdf"], allow_multiple=False)

    def _pick_file(self, types: List[ft.FilePickerFileType], on_picked: Callable[[str], None]) -> None:
        self._pick_callback = on_picked
        self.file_picker.pick_files(file_type=types[0], allow_multiple=False)

    def _pick_files_merge(self) -> None:
        def on_paths(paths: List[str]) -> None:
            for path in paths:
                if path not in self.merge_paths:
                    self.merge_paths.append(path)
                    self.merge_list.controls.append(ft.Text(os.path.basename(path)))
            if self.merge_paths and not self.merge_output.value:
                self.merge_output.value = os.path.join(
                    _app_output_dir(), "merged_%d.pdf" % len(self.merge_paths)
                )
            self.page.update()

        self._pick_callback = lambda path: on_paths([path])
        self.file_picker.pick_files(allowed_extensions=["pdf"], allow_multiple=True)

    def _pick_save(self, field: ft.TextField, ext: str) -> None:
        self._save_callback = lambda path: self._set_field(field, path)
        self.save_picker.save_file(file_name=os.path.basename(field.value or "output" + ext))

    def _set_field(
        self,
        field: ft.TextField,
        path: str,
        extra: Optional[Callable[[str], None]] = None,
    ) -> None:
        field.value = path
        if extra:
            extra(path)
        self.page.update()

    def _on_file_picked(self, e: ft.FilePickerResultEvent) -> None:
        if not self._pick_callback:
            return
        paths: List[str] = []
        if e.files:
            for item in e.files:
                if item.path:
                    paths.append(item.path)
        elif e.path:
            paths.append(e.path)
        if not paths:
            return
        if len(paths) == 1:
            self._pick_callback(paths[0])
        else:
            for path in paths:
                self._pick_callback(path)
        self._pick_callback = None

    def _on_save_picked(self, e: ft.FilePickerResultEvent) -> None:
        if self._save_callback and e.path:
            self._save_callback(e.path)
        self._save_callback = None

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
            self._on_error("添加水印", ValueError("请选择输入和输出 PDF"))
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
            self._on_error("PDF 压缩", ValueError("请选择输入和输出 PDF"))
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
            self._on_error("合并 PDF", ValueError("请选择输出路径"))
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
            self._on_error("拆分 PDF", ValueError("请选择 PDF 和输出目录"))
            return

        def job():
            os.makedirs(out_dir, exist_ok=True)
            if self.split_mode.value == "each":
                return split_every_page(src, out_dir)
            total = pdf_page_count(src)
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
            "请重新安装 arm64-v8a 包，或用 adb logcat 查看详细日志。",
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
