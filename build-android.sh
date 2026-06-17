#!/usr/bin/env bash
# 本地构建 Android APK（macOS / Linux / Windows Git Bash）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> 安装构建依赖"
python3 -m pip install -U pip
python3 -m pip install "flet[all]>=0.25.0"

echo "==> 构建 APK（按 CPU 架构分包，体积更小）"
flet build apk --split-per-abi -v

echo ""
echo "构建完成，产物目录："
find build -name "*.apk" -print 2>/dev/null || true
