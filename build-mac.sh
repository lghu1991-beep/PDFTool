#!/bin/bash
# mac 分支：在 macOS 上打包 PDFTool.app
set -e
cd "$(dirname "$0")"
ROOT="$PWD"

echo "=== PDFTool macOS 打包 ==="

if ! command -v python3 >/dev/null 2>&1; then
  echo "[错误] 未找到 python3"
  exit 1
fi

python3 -c "import tkinter" 2>/dev/null || {
  echo "[错误] 当前 Python 无 tkinter，请安装官方 Python 或: brew install python-tk@3.11"
  exit 1
}

python3 -m pip install -U pip
python3 -m pip install -r requirements.txt

echo ""
echo "开始打包 PDFTool.app ..."
python3 -m PyInstaller --noconfirm --clean PDFTool-mac.spec

if [ -d "dist/PDFTool.app" ]; then
  echo ""
  echo "成功：dist/PDFTool.app"
  echo "运行：open dist/PDFTool.app"
  echo "或：./run-mac.sh"
else
  echo "[错误] 未找到 dist/PDFTool.app"
  exit 1
fi
