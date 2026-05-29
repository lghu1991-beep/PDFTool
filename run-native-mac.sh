#!/bin/bash
# 开发模式：Objective-C 界面 + 源码 Python 引擎
set -e
cd "$(dirname "$0")"
export PDFTOOL_ROOT="$PWD"

if ! python3 -c "import pypdf, reportlab, PIL" 2>/dev/null; then
  echo "安装 Python 依赖…"
  python3 -m pip install -r requirements.txt
fi

cd macOS/PDFToolNativeOC
make
echo "启动 PDFTool 原生版（Objective-C）…"
exec ./PDFToolNative
