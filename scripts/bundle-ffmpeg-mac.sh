#!/bin/bash
# 将本机 ffmpeg / ffprobe 及其动态库打入 .app/Contents/Resources
set -e

APP="${1:?用法: bundle-ffmpeg-mac.sh /path/to/App.app}"
BIN_DIR="$APP/Contents/Resources/bin"
LIB_DIR="$APP/Contents/Resources/lib/ffmpeg"

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  echo "[错误] 构建机未找到 ffmpeg/ffprobe，请先执行: brew install ffmpeg" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$LIB_DIR"
cp -f "$(command -v ffmpeg)" "$BIN_DIR/ffmpeg"
cp -f "$(command -v ffprobe)" "$BIN_DIR/ffprobe"
chmod +x "$BIN_DIR/ffmpeg" "$BIN_DIR/ffprobe"

is_system_lib() {
  case "$1" in
    /usr/lib/*|/System/*|/Library/Developer/*) return 0 ;;
  esac
  return 1
}

should_skip_dep() {
  case "$1" in
    ""|@executable_path/*|@loader_path/*|@rpath/*) return 0 ;;
  esac
  is_system_lib "$1" && return 0
  return 1
}

copy_deps_for() {
  local target="$1"
  local dep base dest
  while IFS= read -r dep; do
    should_skip_dep "$dep" && continue
    [ -f "$dep" ] || continue
    base="$(basename "$dep")"
    dest="$LIB_DIR/$base"
    if [ ! -f "$dest" ]; then
      cp -f "$dep" "$dest"
      copy_deps_for "$dest"
    fi
  done < <(otool -L "$target" 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//' | cut -d' ' -f1)
}

fix_deps_for() {
  local target="$1"
  local dep base
  install_name_tool -add_rpath "@executable_path/../lib/ffmpeg" "$target" 2>/dev/null || true
  while IFS= read -r dep; do
    should_skip_dep "$dep" && continue
    [ -f "$dep" ] || continue
    base="$(basename "$dep")"
    install_name_tool -change "$dep" "@executable_path/../lib/ffmpeg/$base" "$target" 2>/dev/null || true
  done < <(otool -L "$target" 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//' | cut -d' ' -f1)
}

echo "打包 ffmpeg → $BIN_DIR"
copy_deps_for "$BIN_DIR/ffmpeg"
copy_deps_for "$BIN_DIR/ffprobe"

for lib in "$LIB_DIR"/*; do
  [ -f "$lib" ] || continue
  copy_deps_for "$lib"
done

fix_deps_for "$BIN_DIR/ffmpeg"
fix_deps_for "$BIN_DIR/ffprobe"
for lib in "$LIB_DIR"/*; do
  [ -f "$lib" ] || continue
  fix_deps_for "$lib"
done

"$BIN_DIR/ffmpeg" -version | head -n 1
"$BIN_DIR/ffprobe" -version | head -n 1
echo "ffmpeg 已内置到 app（含依赖库 $(ls "$LIB_DIR" 2>/dev/null | wc -l | tr -d ' ') 个）"
