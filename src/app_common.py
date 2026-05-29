# -*- coding: utf-8 -*-
"""登录与窗口通用逻辑。"""

from __future__ import annotations

import hashlib
import sys
import tkinter as tk
from tkinter import messagebox, ttk

AUTH_MAX_RETRY = 3
AUTH_PASSWORD_SHA256 = "a3dbd9941a7e6f31eecbdcf93ee8e822a1c3228f75fe3596ec2cd0de690d27d1"


def center_window(win: tk.Misc, width: int, height: int) -> None:
    win.update_idletasks()
    sw = win.winfo_screenwidth()
    sh = win.winfo_screenheight()
    x = max(0, (sw - width) // 2)
    y = max(0, (sh - height) // 2)
    win.geometry("%dx%d+%d+%d" % (width, height, x, y))


def bring_to_front(win: tk.Misc) -> None:
    win.update_idletasks()
    if isinstance(win, (tk.Tk, tk.Toplevel)):
        win.deiconify()
    win.lift()
    win.focus_force()
    if sys.platform == "darwin":
        try:
            win.attributes("-topmost", True)
            win.after(400, lambda: win.attributes("-topmost", False))
        except tk.TclError:
            pass
    win.update()


def verify_startup_password() -> bool:
    for attempt in range(AUTH_MAX_RETRY):
        login = tk.Tk()
        login.title("工具集 - 身份验证")
        login.resizable(False, False)
        center_window(login, 360, 140)

        if sys.platform == "darwin":
            try:
                login.attributes("-topmost", True)
            except tk.TclError:
                pass

        verified = {"ok": False}
        pwd_var = tk.StringVar()

        frame = ttk.Frame(login, padding=16)
        frame.pack(fill=tk.BOTH, expand=True)
        ttk.Label(frame, text="请输入使用密码：").pack(anchor=tk.W)
        entry = ttk.Entry(frame, textvariable=pwd_var, show="*")
        entry.pack(fill=tk.X, pady=(10, 14))
        entry.focus_set()

        btns = ttk.Frame(frame)
        btns.pack(fill=tk.X)

        def on_confirm(_event=None) -> None:
            digest = hashlib.sha256(pwd_var.get().encode("utf-8")).hexdigest()
            if digest == AUTH_PASSWORD_SHA256:
                verified["ok"] = True
                login.destroy()
            else:
                messagebox.showerror("错误", "密码错误，请重试。", parent=login)
                entry.select_range(0, tk.END)
                entry.focus_set()

        def on_cancel() -> None:
            login.destroy()

        ttk.Button(btns, text="取消", command=on_cancel).pack(side=tk.RIGHT)
        ttk.Button(btns, text="确定", command=on_confirm).pack(side=tk.RIGHT, padx=(0, 8))
        login.bind("<Return>", on_confirm)
        login.bind("<Escape>", lambda _e: on_cancel())
        login.protocol("WM_DELETE_WINDOW", on_cancel)

        bring_to_front(login)
        login.mainloop()

        if verified["ok"]:
            return True
        if attempt < AUTH_MAX_RETRY - 1:
            continue
        messagebox.showerror("错误", "已取消或密码错误次数过多。")
        return False
    return False
