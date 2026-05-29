#!/bin/bash
# 构建 macOS 原生 Objective-C 应用（不依赖 Tkinter / Swift）
set -e
cd "$(dirname "$0")"
ROOT="$PWD"

echo "=== PDFTool 原生 macOS 构建 (Objective-C) ==="

if ! command -v python3 >/dev/null 2>&1; then
  echo "[错误] 未找到 python3"
  exit 1
fi
if ! command -v clang >/dev/null 2>&1; then
  echo "[错误] 未找到 clang，请安装 Xcode Command Line Tools：xcode-select --install"
  exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  echo "[错误] 打包需要本机 ffmpeg，请先执行: brew install ffmpeg"
  exit 1
fi

python3 -m pip install -U pip
python3 -m pip install -r requirements.txt

echo ""
echo "[1/3] 打包 Python 引擎 PDFToolEngine …"
python3 -m PyInstaller --noconfirm --clean PDFTool-engine.spec

ENGINE="$ROOT/dist/PDFToolEngine"
if [ ! -f "$ENGINE" ]; then
  echo "[错误] 未找到 $ENGINE"
  exit 1
fi
chmod +x "$ENGINE"

echo ""
echo "[2/3] 编译 Objective-C 应用 …"
cd "$ROOT/macOS/PDFToolNativeOC"
make clean
make
BIN="$ROOT/macOS/PDFToolNativeOC/PDFToolNative"
if [ ! -f "$BIN" ]; then
  echo "[错误] 未找到 $BIN"
  exit 1
fi

APP="$ROOT/dist/PDFToolNative.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/PDFToolNative"
cp "$ENGINE" "$APP/Contents/Resources/PDFToolEngine"
chmod +x "$APP/Contents/MacOS/PDFToolNative" "$APP/Contents/Resources/PDFToolEngine"

echo ""
echo "[3/3] 打包内置 ffmpeg …"
chmod +x "$ROOT/scripts/bundle-ffmpeg-mac.sh"
"$ROOT/scripts/bundle-ffmpeg-mac.sh" "$APP"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>PDFToolNative</string>
  <key>CFBundleIdentifier</key>
  <string>com.qy.pdftool.native</string>
  <key>CFBundleName</key>
  <string>工具集</string>
  <key>CFBundleDisplayName</key>
  <string>工具集</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo ""
echo "成功：$APP"
echo "运行：open \"$APP\""
