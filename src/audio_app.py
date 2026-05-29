# -*- coding: utf-8 -*-
"""音频编辑窗口（ffmpeg）。"""

from __future__ import annotations

import os
import tempfile
import threading
import tkinter as tk
import uuid
from tkinter import filedialog, messagebox, ttk

from app_common import bring_to_front, center_window
from ffmpeg_audio import (
    availability_hint,
    export_audio,
    extract_from_video,
    format_time,
    is_available,
    is_video,
    play_preview,
    probe_duration,
    trim_audio,
)

BG = "#e8f4fc"
BAR = "#5c94d1"
TITLE = "#1a3a6e"


class AudioEditWindow(tk.Toplevel):
    def __init__(self, master: tk.Misc) -> None:
        super().__init__(master)
        self.title("AudioEdit")
        self.geometry("920x560")
        self.minsize(720, 480)
        self.configure(bg=BG)
        self._loaded_path: str | None = None
        self._duration = 0.0
        self._busy = False
        self._build_ui()
        self.protocol("WM_DELETE_WINDOW", self.destroy)
        center_window(self, 920, 560)
        if not is_available():
            self.after(200, lambda: messagebox.showwarning("需要 ffmpeg", availability_hint(), parent=self))

    def _build_ui(self) -> None:
        top = tk.Frame(self, bg=BG)
        top.pack(fill=tk.BOTH, expand=True, padx=0, pady=(0, 56))

        tk.Label(top, text="AudioEdit", font=("", 22, "bold"), bg=BG, fg=TITLE).pack(pady=(16, 20))

        btn_row = tk.Frame(top, bg=BG)
        btn_row.pack(pady=(0, 12))
        for text, cmd in (
            ("从视频中提取音频", self._pick_video_extract),
            ("添加文件", self._pick_media),
            ("录音", self._record_stub),
        ):
            tk.Button(
                btn_row,
                text=text,
                font=("", 11),
                bg="white",
                fg=TITLE,
                relief=tk.FLAT,
                padx=16,
                pady=10,
                command=cmd,
            ).pack(side=tk.LEFT, padx=8)

        self._hint = tk.Label(top, text="或拖放这里", font=("", 13), bg=BG, fg="#666")
        self._hint.pack(pady=8)
        self._file_label = tk.Label(top, text="", font=("", 11), bg=BG, fg=TITLE)

        self._trim_frame = ttk.LabelFrame(top, text="剪辑片段", padding=10)
        trim_inner = ttk.Frame(self._trim_frame)
        trim_inner.pack(fill=tk.X)
        ttk.Label(trim_inner, text="开始").grid(row=0, column=0, padx=4)
        self._start_var = tk.StringVar(value="0")
        ttk.Entry(trim_inner, textvariable=self._start_var, width=12).grid(row=0, column=1, padx=4)
        ttk.Label(trim_inner, text="结束").grid(row=0, column=2, padx=4)
        self._end_var = tk.StringVar()
        ttk.Entry(trim_inner, textvariable=self._end_var, width=12).grid(row=0, column=3, padx=4)
        ttk.Button(trim_inner, text="应用剪辑", command=self._apply_trim).grid(row=0, column=4, padx=8)

        bar = tk.Frame(self, bg=BAR, height=56)
        bar.pack(fill=tk.X, side=tk.BOTTOM)
        bar.pack_propagate(False)

        self._play_btn = tk.Button(bar, text="▶", width=3, command=self._toggle_play, state=tk.DISABLED)
        self._play_btn.pack(side=tk.LEFT, padx=(16, 8), pady=12)
        self._time_var = tk.StringVar(value="00:00.00 / 00:00.00")
        tk.Label(bar, textvariable=self._time_var, bg=BAR, fg="white", font=("Consolas", 11)).pack(
            side=tk.LEFT, pady=12
        )

        right = tk.Frame(bar, bg=BAR)
        right.pack(side=tk.RIGHT, padx=16, pady=10)
        tk.Label(right, text="格式:", bg=BAR, fg="white").pack(side=tk.LEFT, padx=(0, 4))
        self._fmt = ttk.Combobox(right, values=["mp3", "m4a", "wav", "aac"], width=6, state="readonly")
        self._fmt.set("mp3")
        self._fmt.pack(side=tk.LEFT, padx=(0, 12))
        self._save_btn = tk.Button(right, text="保存", command=self._save, state=tk.DISABLED)
        self._save_btn.pack(side=tk.LEFT)

    def _set_busy(self, busy: bool, status: str = "") -> None:
        self._busy = busy
        self.title("AudioEdit - %s" % status if busy and status else "AudioEdit")
        state = tk.DISABLED if busy or not self._loaded_path else tk.NORMAL
        self._save_btn.config(state=state)
        self._play_btn.config(state=state)

    def _run_async(self, name: str, fn) -> None:
        if self._busy:
            return
        self._set_busy(True, "%s 处理中…" % name)

        def worker():
            try:
                result = fn()
                self.after(0, lambda: self._on_ok(name, result))
            except Exception as exc:  # noqa: BLE001
                self.after(0, lambda: self._on_err(name, exc))

        threading.Thread(target=worker, daemon=True).start()

    def _on_ok(self, name: str, result) -> None:
        self._set_busy(False)
        if result:
            messagebox.showinfo("完成", "%s\n\n%s" % (name, result), parent=self)

    def _on_err(self, name: str, exc: Exception) -> None:
        self._set_busy(False)
        messagebox.showerror(name + "失败", str(exc), parent=self)

    def _load_file(self, path: str) -> None:
        self._loaded_path = path
        self._hint.config(text="")
        self._file_label.config(text=os.path.basename(path))
        self._file_label.pack(pady=4)
        self._trim_frame.pack(fill=tk.X, padx=40, pady=12)
        self._start_var.set("0")
        self._end_var.set("")
        self._duration = 0.0
        self._time_var.set("00:00.00 / --:--.--")
        self._set_busy(False)

        def worker():
            try:
                dur = probe_duration(path)
                self.after(0, lambda: self._apply_duration(dur))
            except Exception as exc:  # noqa: BLE001
                self.after(0, lambda: messagebox.showwarning("提示", str(exc), parent=self))

        threading.Thread(target=worker, daemon=True).start()

    def _apply_duration(self, dur: float) -> None:
        self._duration = dur
        self._end_var.set(format_time(dur))
        self._time_var.set("00:00.00 / %s" % format_time(dur))

    def _import_path(self, path: str) -> None:
        if not path:
            return
        if is_video(path):
            self._extract_video(path)
        else:
            self._load_file(path)

    def _pick_media(self) -> None:
        path = filedialog.askopenfilename(
            parent=self,
            filetypes=[
                ("音频/视频", "*.mp3 *.m4a *.wav *.aac *.flac *.mp4 *.mov *.mkv"),
                ("All", "*.*"),
            ],
        )
        if path:
            self._import_path(path)

    def _pick_video_extract(self) -> None:
        path = filedialog.askopenfilename(
            parent=self,
            filetypes=[("视频", "*.mp4 *.mov *.mkv *.avi *.webm *.m4v")],
        )
        if path:
            self._extract_video(path)

    def _extract_video(self, video_path: str) -> None:
        fmt = self._fmt.get() or "mp3"
        out = filedialog.asksaveasfilename(
            parent=self,
            defaultextension="." + fmt,
            filetypes=[(fmt.upper(), "*.%s" % fmt)],
            initialfile=os.path.splitext(os.path.basename(video_path))[0] + "." + fmt,
        )
        if not out:
            return

        def job():
            extract_from_video(video_path, out, fmt)
            return "已提取到：\n%s" % out

        def on_ok(_name, result):
            self._set_busy(False)
            messagebox.showinfo("完成", result, parent=self)
            self._load_file(out)

        def on_err(_name, exc):
            self._set_busy(False)
            messagebox.showerror("提取失败", str(exc), parent=self)

        self._set_busy(True, "正在提取…")

        def worker():
            try:
                r = job()
                self.after(0, lambda: on_ok("", r))
            except Exception as exc:  # noqa: BLE001
                self.after(0, lambda: on_err("", exc))

        threading.Thread(target=worker, daemon=True).start()

    def _apply_trim(self) -> None:
        if not self._loaded_path:
            return
        start = self._start_var.get().strip()
        end = self._end_var.get().strip()
        if not start or not end:
            messagebox.showwarning("提示", "请填写开始与结束时间", parent=self)
            return
        ext = os.path.splitext(self._loaded_path)[1].lstrip(".") or "mp3"
        temp = os.path.join(tempfile.gettempdir(), "%s.%s" % (uuid.uuid4().hex, ext))

        def worker():
            try:
                trim_audio(self._loaded_path, temp, start, end)

                def ui_done():
                    self._set_busy(False)
                    self._load_file(temp)
                    messagebox.showinfo("完成", "剪辑已应用。", parent=self)

                self.after(0, ui_done)
            except Exception as exc:  # noqa: BLE001
                self.after(0, lambda: self._on_err("剪辑", exc))

        self._set_busy(True, "正在剪辑…")
        threading.Thread(target=worker, daemon=True).start()

    def _save(self) -> None:
        if not self._loaded_path:
            return
        fmt = self._fmt.get() or "mp3"
        out = filedialog.asksaveasfilename(
            parent=self,
            defaultextension="." + fmt,
            filetypes=[(fmt.upper(), "*.%s" % fmt)],
            initialfile=os.path.splitext(os.path.basename(self._loaded_path))[0] + "." + fmt,
        )
        if not out:
            return

        def job():
            export_audio(self._loaded_path, out, fmt)
            return "已保存到：\n%s" % out

        self._run_async("导出", job)

    def _toggle_play(self) -> None:
        if not self._loaded_path:
            return
        try:
            play_preview(self._loaded_path)
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("无法播放", str(exc), parent=self)

    def _record_stub(self) -> None:
        messagebox.showinfo("提示", "录音功能开发中，请先使用「添加文件」导入。", parent=self)
