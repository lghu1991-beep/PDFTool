# -*- mode: python ; coding: utf-8 -*-
"""macOS 打包：生成 dist/PDFTool.app"""

from PyInstaller.utils.hooks import collect_all

block_cipher = None
datas = []
binaries = []
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
    argv_emulation=False,
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
