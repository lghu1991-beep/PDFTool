#!/bin/bash
# 在 macOS/Linux 上打包 Windows 发布 zip（需在 Windows 上运行 build.bat 生成 exe）
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/release"
ZIP="$OUT/PDFTool-Windows.zip"

mkdir -p "$OUT"
rm -f "$ZIP"

cd "$ROOT"
zip -r "$ZIP" \
  src \
  requirements.txt \
  PDFTool.spec \
  build.bat \
  run-dev.bat \
  PDFTool.bat \
  安装并打包.bat \
  安装Python环境.bat \
  安装依赖并运行.bat \
  检查环境.bat \
  _paths.bat \
  runtime/python-3.11.9-amd64.exe \
  runtime/get-pip.py \
  runtime/说明.txt \
  使用说明-Windows.txt \
  从压缩包到exe完整步骤.txt \
  README.md \
  -x "*.pyc" -x "*__pycache__*"

echo "已生成: $ZIP"
ls -lh "$ZIP"
