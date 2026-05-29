# -*- mode: python ; coding: utf-8 -*-
"""macOS 打包：生成 dist/PDFTool.app"""

import os
import sys

from PyInstaller.utils.hooks import collect_all, collect_data_files

block_cipher = None
datas = []
binaries = []

# macOS 打包必须带上 Tcl/Tk 资源，否则窗口有框无内容
try:
    datas += collect_data_files("tkinter")
except Exception:
    pass
if sys.platform == "darwin":
    for lib_name in ("tcl8.6", "tk8.6"):
        for base in (sys.base_prefix, os.path.join(sys.base_prefix, "Frameworks")):
            candidate = os.path.join(base, "lib", lib_name)
            if os.path.isdir(candidate):
                datas.append((candidate, os.path.join("lib", lib_name)))
                break
hiddenimports = [
    "pdf_core",
    "word_convert",
    "startup_log",
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
    ["src/main.py"],
    pathex=["src"],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="PDFTool",
    debug=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=True,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    name="PDFTool",
)

app = BUNDLE(
    coll,
    name="PDFTool.app",
    icon=None,
    bundle_identifier="com.qy.pdftool",
    info_plist={
        "NSHighResolutionCapable": True,
        "CFBundleName": "PDFTool",
        "CFBundleDisplayName": "PDFTool",
    },
)
