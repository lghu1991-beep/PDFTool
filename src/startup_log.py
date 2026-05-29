# -*- coding: utf-8 -*-
"""启动异常写入日志，便于 Win10 等环境排查 exe 打不开。"""

from __future__ import annotations

import os
import sys
import traceback
from datetime import datetime
from typing import Optional


def log_path() -> str:
    if sys.platform == "darwin":
        folder = os.path.join(os.path.expanduser("~"), "Library", "Logs", "PDFTool")
    else:
        base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
        folder = os.path.join(base, "PDFTool")
    os.makedirs(folder, exist_ok=True)
    return os.path.join(folder, "startup.log")


def write_log(message: str) -> None:
    try:
        with open(log_path(), "a", encoding="utf-8") as f:
            f.write("[%s] %s\n" % (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), message))
    except OSError:
        pass


def show_fatal(title: str, message: str) -> None:
    write_log("%s: %s" % (title, message))
    try:
        import tkinter as tk
        from tkinter import messagebox

        root = tk.Tk()
        root.withdraw()
        messagebox.showerror(title, message + "\n\n日志：%s" % log_path(), parent=root)
        root.destroy()
    except Exception:
        try:
            import ctypes

            ctypes.windll.user32.MessageBoxW(0, message + "\n\n日志：" + log_path(), title, 0x10)
        except Exception:
            pass


def run_main(main_func) -> None:
    write_log("PDFTool 启动")
    try:
        main_func()
    except Exception:
        err = traceback.format_exc()
        write_log("启动失败:\n" + err)
        show_fatal("PDFTool 启动失败", "程序异常退出，请把日志发给维护人员。\n\n" + err[-1200:])
