# -*- coding: utf-8 -*-
"""工具集入口页。"""

from __future__ import annotations

import tkinter as tk
from tkinter import ttk

from app_common import bring_to_front, center_window
from audio_app import AudioEditWindow
from pdf_app import PDFToolApp


class HubApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("工具集")
        self.geometry("640x380")
        self.minsize(520, 320)
        self.configure(bg="#f7f7f7")
        self._pdf_win: PDFToolApp | None = None
        self._audio_win: AudioEditWindow | None = None
        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self._on_quit)
        center_window(self, 640, 380)

    def _build_ui(self) -> None:
        ttk.Label(self, text="工具集", font=("", 22, "bold")).pack(pady=(28, 6))
        ttk.Label(self, text="选择要使用的工具", foreground="#666").pack(pady=(0, 24))

        cards = ttk.Frame(self)
        cards.pack(fill=tk.BOTH, expand=True, padx=40)

        self._add_card(cards, 0, "PDF 工具", "Word 转 PDF · 水印 · 压缩 · 合并 · 拆分", self._open_pdf)
        self._add_card(cards, 1, "MP3 / 音频编辑", "提取 · 剪辑 · 导出", self._open_audio)

        ttk.Label(self, text="关闭此窗口将退出应用", font=("", 9), foreground="#999").pack(pady=12)

    def _add_card(self, parent: ttk.Frame, column: int, title: str, subtitle: str, command) -> None:
        frame = tk.Frame(parent, bg="white", highlightthickness=1, highlightbackground="#d8d8d8")
        frame.grid(row=0, column=column, padx=12, sticky="nsew")
        parent.columnconfigure(column, weight=1)

        tk.Label(frame, text=subtitle, bg="white", fg="#666", font=("", 10), wraplength=220, justify=tk.LEFT).pack(
            anchor=tk.W, padx=16, pady=(16, 8)
        )
        btn = tk.Button(
            frame,
            text=title,
            font=("", 14, "bold"),
            bg="white",
            fg="#1a3a6e",
            activebackground="#f0f4fa",
            relief=tk.FLAT,
            borderwidth=0,
            command=command,
        )
        btn.pack(anchor=tk.W, padx=16, pady=(0, 16))

    def _open_pdf(self) -> None:
        if self._pdf_win is None or not self._pdf_win.winfo_exists():
            self._pdf_win = PDFToolApp(self)
        bring_to_front(self._pdf_win)

    def _open_audio(self) -> None:
        if self._audio_win is None or not self._audio_win.winfo_exists():
            self._audio_win = AudioEditWindow(self)
        bring_to_front(self._audio_win)

    def _on_quit(self) -> None:
        for win in (self._pdf_win, self._audio_win):
            if win is not None and win.winfo_exists():
                win.destroy()
        self.destroy()
