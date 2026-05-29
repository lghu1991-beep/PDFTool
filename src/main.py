# -*- coding: utf-8 -*-
"""工具集 - Windows / 跨平台 Tkinter 入口。"""

from __future__ import annotations

import os
import sys

# PyInstaller .app 若未指定 Tcl/Tk 路径，macOS 上常见「有窗口无内容」
if getattr(sys, "frozen", False):
    _meipass = getattr(sys, "_MEIPASS", "")
    for _lib, _env in (("tcl8.6", "TCL_LIBRARY"), ("tk8.6", "TK_LIBRARY")):
        _path = os.path.join(_meipass, "lib", _lib)
        if os.path.isdir(_path):
            os.environ[_env] = _path

if getattr(sys, "frozen", False):
    BASE_DIR = sys._MEIPASS  # type: ignore[attr-defined]
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, BASE_DIR)

_IMPORT_ERROR = None
try:
    from hub_app import HubApp  # noqa: E402
except Exception as exc:  # noqa: BLE001
    _IMPORT_ERROR = exc


def main() -> None:
    from app_common import bring_to_front, verify_startup_password

    if not verify_startup_password():
        return
    app = HubApp()
    bring_to_front(app)
    app.mainloop()


if __name__ == "__main__":
    from startup_log import run_main, show_fatal

    if _IMPORT_ERROR is not None:
        import traceback

        show_fatal(
            "工具集模块加载失败",
            traceback.format_exception_only(type(_IMPORT_ERROR), _IMPORT_ERROR)[0],
        )
    else:
        run_main(main)
