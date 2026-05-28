# -*- coding: utf-8 -*-
"""PDFTool - Windows PDF 小工具。"""

from __future__ import annotations

import os
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

if getattr(sys, "frozen", False):
    BASE_DIR = sys._MEIPASS  # type: ignore[attr-defined]
    APP_DIR = os.path.dirname(sys.executable)
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    APP_DIR = BASE_DIR

sys.path.insert(0, BASE_DIR)

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
from word_convert import word_to_pdf  # noqa: E402


class PDFToolApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("PDFTool - PDF 工具")
        self.geometry("660x560")
        self.minsize(580, 500)
        self._build_ui()

    def _build_ui(self) -> None:
        style = ttk.Style(self)
        if "vista" in style.theme_names():
            style.theme_use("vista")

        notebook = ttk.Notebook(self)
        notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        self._tab_word = ttk.Frame(notebook, padding=12)
        self._tab_watermark = ttk.Frame(notebook, padding=12)
        self._tab_compress = ttk.Frame(notebook, padding=12)
        self._tab_merge = ttk.Frame(notebook, padding=12)
        self._tab_split = ttk.Frame(notebook, padding=12)

        notebook.add(self._tab_word, text="Word 转 PDF")
        notebook.add(self._tab_watermark, text="水印")
        notebook.add(self._tab_compress, text="PDF 压缩")
        notebook.add(self._tab_merge, text="合并 PDF")
        notebook.add(self._tab_split, text="拆分 PDF")

        self._build_word_tab()
        self._build_watermark_tab()
        self._build_compress_tab()
        self._build_merge_tab()
        self._build_split_tab()

        self.status = tk.StringVar(value="就绪")
        ttk.Label(self, textvariable=self.status, anchor=tk.W).pack(
            fill=tk.X, padx=10, pady=(0, 8)
        )

    def _build_word_tab(self) -> None:
        frame = self._tab_word
        ttk.Label(
            frame,
            text="支持 .doc / .docx / .wps / .rtf 等。\n"
            "优先使用 LibreOffice 转换（免费）；未安装时尝试 Microsoft Word。",
            justify=tk.LEFT,
        ).pack(anchor=tk.W)

        self.word_input = tk.StringVar()
        self.word_output = tk.StringVar()
        self._file_row(frame, "源文件", self.word_input, [("Office", "*.doc *.docx *.wps *.rtf *.odt")])
        self._save_row(frame, "输出 PDF", self.word_output, [("PDF", "*.pdf")])

        ttk.Button(frame, text="开始转换", command=self._run_word_convert).pack(
            anchor=tk.E, pady=(12, 0)
        )

    def _build_watermark_tab(self) -> None:
        frame = self._tab_watermark
        self.wm_input = tk.StringVar()
        self.wm_output = tk.StringVar()
        self.wm_mode = tk.StringVar(value="text")

        self._file_row(frame, "PDF 文件", self.wm_input, [("PDF", "*.pdf")])
        self._save_row(frame, "输出 PDF", self.wm_output, [("PDF", "*.pdf")])

        mode_row = ttk.Frame(frame)
        mode_row.pack(fill=tk.X, pady=(8, 4))
        ttk.Label(mode_row, text="水印类型", width=10).pack(side=tk.LEFT)
        ttk.Radiobutton(mode_row, text="文字", variable=self.wm_mode, value="text", command=self._sync_wm_mode).pack(
            side=tk.LEFT
        )
        ttk.Radiobutton(mode_row, text="图片", variable=self.wm_mode, value="image", command=self._sync_wm_mode).pack(
            side=tk.LEFT, padx=8
        )

        self.wm_text_frame = ttk.Frame(frame)
        self.wm_text_frame.pack(fill=tk.X, pady=4)
        self.wm_text = tk.StringVar(value="机密")
        self.wm_opacity = tk.DoubleVar(value=0.25)
        self.wm_angle = tk.DoubleVar(value=45.0)
        self.wm_font = tk.IntVar(value=48)

        row = ttk.Frame(self.wm_text_frame)
        row.pack(fill=tk.X, pady=4)
        ttk.Label(row, text="水印文字", width=10).pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=self.wm_text).pack(side=tk.LEFT, fill=tk.X, expand=True)

        row3 = ttk.Frame(self.wm_text_frame)
        row3.pack(fill=tk.X, pady=4)
        ttk.Label(row3, text="角度/字号", width=10).pack(side=tk.LEFT)
        ttk.Entry(row3, textvariable=self.wm_angle, width=8).pack(side=tk.LEFT)
        ttk.Entry(row3, textvariable=self.wm_font, width=8).pack(side=tk.LEFT, padx=(8, 0))

        self.wm_image_frame = ttk.Frame(frame)
        self.wm_image_path = tk.StringVar()
        self.wm_scale = tk.DoubleVar(value=0.25)
        self.wm_position = tk.StringVar(value="center")

        img_row = ttk.Frame(self.wm_image_frame)
        img_row.pack(fill=tk.X, pady=4)
        ttk.Label(img_row, text="水印图片", width=10).pack(side=tk.LEFT)
        ttk.Entry(img_row, textvariable=self.wm_image_path).pack(side=tk.LEFT, fill=tk.X, expand=True)

        def pick_image():
            path = filedialog.askopenfilename(
                filetypes=[("图片", "*.png *.jpg *.jpeg *.webp *.bmp"), ("All", "*.*")]
            )
            if path:
                self.wm_image_path.set(path)

        ttk.Button(img_row, text="浏览", command=pick_image).pack(side=tk.LEFT, padx=4)

        img_row2 = ttk.Frame(self.wm_image_frame)
        img_row2.pack(fill=tk.X, pady=4)
        ttk.Label(img_row2, text="相对大小", width=10).pack(side=tk.LEFT)
        ttk.Scale(img_row2, from_=0.08, to=0.8, variable=self.wm_scale, orient=tk.HORIZONTAL).pack(
            side=tk.LEFT, fill=tk.X, expand=True
        )

        img_row3 = ttk.Frame(self.wm_image_frame)
        img_row3.pack(fill=tk.X, pady=4)
        ttk.Label(img_row3, text="位置", width=10).pack(side=tk.LEFT)
        ttk.Combobox(
            img_row3,
            textvariable=self.wm_position,
            values=["center", "top-left", "top-right", "bottom-left", "bottom-right"],
            width=16,
            state="readonly",
        ).pack(side=tk.LEFT)
        ttk.Label(img_row3, text="角度", width=6).pack(side=tk.LEFT, padx=(12, 0))
        self.wm_img_angle = tk.DoubleVar(value=0.0)
        ttk.Entry(img_row3, textvariable=self.wm_img_angle, width=8).pack(side=tk.LEFT)

        row2 = ttk.Frame(frame)
        row2.pack(fill=tk.X, pady=4)
        ttk.Label(row2, text="透明度", width=10).pack(side=tk.LEFT)
        ttk.Scale(row2, from_=0.05, to=0.9, variable=self.wm_opacity, orient=tk.HORIZONTAL).pack(
            side=tk.LEFT, fill=tk.X, expand=True
        )

        ttk.Button(frame, text="添加水印", command=self._run_watermark).pack(anchor=tk.E, pady=(12, 0))
        self._sync_wm_mode()

    def _sync_wm_mode(self) -> None:
        if self.wm_mode.get() == "image":
            self.wm_text_frame.pack_forget()
            self.wm_image_frame.pack(fill=tk.X, pady=4)
        else:
            self.wm_image_frame.pack_forget()
            self.wm_text_frame.pack(fill=tk.X, pady=4)

    def _build_compress_tab(self) -> None:
        frame = self._tab_compress
        ttk.Label(
            frame,
            text="轻/中：内置流压缩（纯文本 PDF 适用）\n"
            "强：图片重采样至 72dpi（扫描件/大图 PDF）；若已装 Ghostscript 则优先使用",
            justify=tk.LEFT,
        ).pack(anchor=tk.W)

        self.compress_input = tk.StringVar()
        self.compress_output = tk.StringVar()
        self.compress_level = tk.StringVar(value="medium")

        self._file_row(frame, "PDF 文件", self.compress_input, [("PDF", "*.pdf")])
        self._save_row(frame, "输出 PDF", self.compress_output, [("PDF", "*.pdf")])

        level_row = ttk.Frame(frame)
        level_row.pack(fill=tk.X, pady=8)
        ttk.Label(level_row, text="压缩级别", width=10).pack(side=tk.LEFT)
        ttk.Radiobutton(level_row, text="轻", variable=self.compress_level, value="light").pack(side=tk.LEFT)
        ttk.Radiobutton(level_row, text="中（推荐）", variable=self.compress_level, value="medium").pack(
            side=tk.LEFT, padx=8
        )
        ttk.Radiobutton(level_row, text="强", variable=self.compress_level, value="strong").pack(side=tk.LEFT)

        ttk.Button(frame, text="开始压缩", command=self._run_compress).pack(anchor=tk.E, pady=(12, 0))

    def _build_merge_tab(self) -> None:
        frame = self._tab_merge
        ttk.Label(frame, text="按顺序合并多个 PDF：").pack(anchor=tk.W)
        list_frame = ttk.Frame(frame)
        list_frame.pack(fill=tk.BOTH, expand=True, pady=8)

        self.merge_list = tk.Listbox(list_frame, height=8)
        self.merge_list.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll = ttk.Scrollbar(list_frame, command=self.merge_list.yview)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)
        self.merge_list.config(yscrollcommand=scroll.set)

        btns = ttk.Frame(frame)
        btns.pack(fill=tk.X)
        ttk.Button(btns, text="添加文件", command=self._merge_add).pack(side=tk.LEFT)
        ttk.Button(btns, text="移除选中", command=self._merge_remove).pack(side=tk.LEFT, padx=6)
        ttk.Button(btns, text="清空", command=self._merge_clear).pack(side=tk.LEFT)

        self.merge_output = tk.StringVar()
        self._save_row(frame, "输出 PDF", self.merge_output, [("PDF", "*.pdf")])
        ttk.Button(frame, text="合并", command=self._run_merge).pack(anchor=tk.E, pady=(8, 0))

    def _build_split_tab(self) -> None:
        frame = self._tab_split
        self.split_input = tk.StringVar()
        self.split_output_dir = tk.StringVar()
        self.split_mode = tk.StringVar(value="range")
        self.split_range = tk.StringVar(value="1-1")

        self._file_row(frame, "PDF 文件", self.split_input, [("PDF", "*.pdf")])

        dir_row = ttk.Frame(frame)
        dir_row.pack(fill=tk.X, pady=6)
        ttk.Label(dir_row, text="输出目录", width=10).pack(side=tk.LEFT)
        ttk.Entry(dir_row, textvariable=self.split_output_dir).pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(dir_row, text="选择", command=self._pick_split_dir).pack(side=tk.LEFT, padx=4)

        mode_row = ttk.Frame(frame)
        mode_row.pack(fill=tk.X, pady=6)
        ttk.Radiobutton(mode_row, text="按页码范围（如 1-3,5-8）", variable=self.split_mode, value="range").pack(
            anchor=tk.W
        )
        ttk.Radiobutton(mode_row, text="每页单独一个 PDF", variable=self.split_mode, value="each").pack(
            anchor=tk.W
        )

        range_row = ttk.Frame(frame)
        range_row.pack(fill=tk.X, pady=6)
        ttk.Label(range_row, text="页码范围", width=10).pack(side=tk.LEFT)
        ttk.Entry(range_row, textvariable=self.split_range).pack(side=tk.LEFT, fill=tk.X, expand=True)

        ttk.Button(frame, text="拆分", command=self._run_split).pack(anchor=tk.E, pady=(12, 0))

    def _file_row(self, parent, label, variable, filetypes):
        row = ttk.Frame(parent)
        row.pack(fill=tk.X, pady=6)
        ttk.Label(row, text=label, width=10).pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=variable).pack(side=tk.LEFT, fill=tk.X, expand=True)

        def pick():
            path = filedialog.askopenfilename(filetypes=filetypes)
            if path:
                variable.set(path)
                if variable is self.word_input:
                    self.word_output.set(os.path.splitext(path)[0] + ".pdf")
                elif variable is self.wm_input:
                    self.wm_output.set(os.path.splitext(path)[0] + "_watermark.pdf")
                elif variable is self.compress_input:
                    self.compress_output.set(os.path.splitext(path)[0] + "_compressed.pdf")
                elif variable is self.split_input:
                    self.split_output_dir.set(os.path.dirname(path))

        ttk.Button(row, text="浏览", command=pick).pack(side=tk.LEFT, padx=4)

    def _save_row(self, parent, label, variable, filetypes):
        row = ttk.Frame(parent)
        row.pack(fill=tk.X, pady=6)
        ttk.Label(row, text=label, width=10).pack(side=tk.LEFT)
        ttk.Entry(row, textvariable=variable).pack(side=tk.LEFT, fill=tk.X, expand=True)

        def pick():
            path = filedialog.asksaveasfilename(defaultextension=".pdf", filetypes=filetypes)
            if path:
                variable.set(path)

        ttk.Button(row, text="浏览", command=pick).pack(side=tk.LEFT, padx=4)

    def _pick_split_dir(self) -> None:
        path = filedialog.askdirectory()
        if path:
            self.split_output_dir.set(path)

    def _merge_add(self) -> None:
        paths = filedialog.askopenfilenames(filetypes=[("PDF", "*.pdf")])
        for path in paths:
            self.merge_list.insert(tk.END, path)

    def _merge_remove(self) -> None:
        sel = list(self.merge_list.curselection())
        for idx in reversed(sel):
            self.merge_list.delete(idx)

    def _merge_clear(self) -> None:
        self.merge_list.delete(0, tk.END)

    def _parse_ranges(self, text: str, total: int):
        ranges = []
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

    def _run_async(self, task_name: str, fn) -> None:
        self.status.set("%s 处理中…" % task_name)

        def worker():
            try:
                result = fn()
                self.after(0, lambda: self._on_success(task_name, result))
            except Exception as exc:
                self.after(0, lambda: self._on_error(task_name, exc))

        threading.Thread(target=worker, daemon=True).start()

    def _on_success(self, task_name: str, result) -> None:
        self.status.set("%s 完成" % task_name)
        if isinstance(result, dict) and "before" in result and "after" in result:
            messagebox.showinfo(
                "完成",
                "%s\n\n方式：%s\n原始：%s\n压缩后：%s\n节省：%s（%.1f%%）\n\n%s"
                % (
                    task_name,
                    result.get("method_label", "内置"),
                    format_size(result["before"]),
                    format_size(result["after"]),
                    format_size(result["saved"]),
                    result["ratio"],
                    result["path"],
                ),
            )
        elif isinstance(result, list):
            messagebox.showinfo("完成", "%s\n\n共 %d 个文件" % (task_name, len(result)))
        else:
            messagebox.showinfo("完成", "%s\n\n%s" % (task_name, result))

    def _on_error(self, task_name: str, exc: Exception) -> None:
        self.status.set("%s 失败" % task_name)
        messagebox.showerror("错误", str(exc))

    def _run_word_convert(self) -> None:
        src = self.word_input.get().strip()
        dst = self.word_output.get().strip()
        if not src or not dst:
            messagebox.showwarning("提示", "请选择源文件和输出路径")
            return

        def job():
            return word_to_pdf(src, dst)

        self._run_async("Word 转 PDF", job)

    def _run_watermark(self) -> None:
        src = self.wm_input.get().strip()
        dst = self.wm_output.get().strip()
        if not src or not dst:
            messagebox.showwarning("提示", "请选择输入和输出 PDF")
            return

        def job():
            opacity = self.wm_opacity.get()
            if self.wm_mode.get() == "image":
                image_path = self.wm_image_path.get().strip()
                if not image_path:
                    raise ValueError("请选择水印图片")
                add_image_watermark(
                    src,
                    dst,
                    image_path,
                    opacity=opacity,
                    scale=self.wm_scale.get(),
                    angle=float(self.wm_img_angle.get()),
                    position=self.wm_position.get(),  # type: ignore[arg-type]
                )
            else:
                add_text_watermark(
                    src,
                    dst,
                    self.wm_text.get(),
                    opacity=opacity,
                    angle=float(self.wm_angle.get()),
                    font_size=int(self.wm_font.get()),
                )
            return dst

        self._run_async("添加水印", job)

    def _run_compress(self) -> None:
        src = self.compress_input.get().strip()
        dst = self.compress_output.get().strip()
        if not src or not dst:
            messagebox.showwarning("提示", "请选择输入和输出 PDF")
            return

        def job():
            return compress_pdf(src, dst, level=self.compress_level.get())  # type: ignore[arg-type]

        self._run_async("PDF 压缩", job)

    def _run_merge(self) -> None:
        items = list(self.merge_list.get(0, tk.END))
        dst = self.merge_output.get().strip()
        if len(items) < 2:
            messagebox.showwarning("提示", "请至少添加 2 个 PDF")
            return
        if not dst:
            messagebox.showwarning("提示", "请选择输出路径")
            return

        def job():
            merge_pdfs(items, dst)
            return dst

        self._run_async("合并 PDF", job)

    def _run_split(self) -> None:
        src = self.split_input.get().strip()
        out_dir = self.split_output_dir.get().strip()
        if not src or not out_dir:
            messagebox.showwarning("提示", "请选择 PDF 和输出目录")
            return

        def job():
            if self.split_mode.get() == "each":
                return split_every_page(src, out_dir)
            total = pdf_page_count(src)
            ranges = self._parse_ranges(self.split_range.get(), total)
            return split_pdf(src, out_dir, ranges)

        self._run_async("拆分 PDF", job)


def main() -> None:
    app = PDFToolApp()
    app.mainloop()


if __name__ == "__main__":
    main()
