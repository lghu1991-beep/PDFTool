#!/usr/bin/env bash
# 本地构建 Android APK（macOS / Linux / Windows Git Bash）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> 安装构建依赖"
python3 -m pip install -U pip
python3 -m pip install "flet[all]==0.28.3"

echo "==> 构建 universal APK（arm64-v8a / armeabi-v7a / x86_64）"
flet build apk -v

echo ""
echo "构建完成，产物目录："
find build -name "*.apk" -print 2>/dev/null || true
if apk=$(find build -name "*.apk" 2>/dev/null | head -1); then
  mkdir -p dist-android
  cp "$apk" dist-android/PDFTool-universal-release.apk
  echo "已复制为 dist-android/PDFTool-universal-release.apk"
fi
