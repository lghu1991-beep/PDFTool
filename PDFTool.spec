# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller 打包配置（Windows 单文件 exe）。"""

import os

from PyInstaller.utils.hooks import collect_all

block_cipher = None

datas = []
binaries = []
hiddenimports = [
    "pdf_core",
    "word_convert",
    "startup_log",
    "app_common",
    "hub_app",
    "pdf_app",
    "audio_app",
    "ffmpeg_audio",
    "fitz",
    "pymupdf",
    "PIL",
    "PIL._imaging",
    "pypdf",
    "reportlab.graphics.barcode.code128",
]

_spec_dir = os.path.dirname(os.path.abspath(SPEC))
_ffmpeg_vendor = os.path.join(_spec_dir, "vendor", "ffmpeg-win")
if os.path.isdir(_ffmpeg_vendor):
    datas.append((_ffmpeg_vendor, "ffmpeg"))

# Explicitly collect package data/binaries so onefile exe can run on clean machines.
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
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
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
    name="PDFTool",  # output: dist/PDFTool.exe
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
