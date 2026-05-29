# -*- mode: python ; coding: utf-8 -*-
"""macOS 原生壳使用的无界面 Python 引擎（不含 Tkinter）。"""

from PyInstaller.utils.hooks import collect_all

block_cipher = None
datas = []
binaries = []
hiddenimports = [
    "pdf_core",
    "word_convert",
    "fitz",
    "pymupdf",
    "PIL",
    "PIL._imaging",
    "pypdf",
    "reportlab.graphics.barcode.code128",
]

for package in ("pymupdf", "reportlab"):
    pkg_datas, pkg_binaries, pkg_hidden = collect_all(package)
    datas += pkg_datas
    binaries += pkg_binaries
    hiddenimports += pkg_hidden

a = Analysis(
    ["src/engine_cli.py"],
    pathex=["src"],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["tkinter", "Tkinter", "_tkinter"],
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name="PDFToolEngine",
    debug=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
