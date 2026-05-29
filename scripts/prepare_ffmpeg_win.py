# -*- coding: utf-8 -*-
"""将本机 ffmpeg 目录复制到 vendor/ffmpeg-win，供 PyInstaller 打入 exe。"""

from __future__ import annotations

import os
import shutil
import sys


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dest = os.path.join(root, "vendor", "ffmpeg-win")
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print("[错误] 未找到 ffmpeg。请安装并加入 PATH，例如：", file=sys.stderr)
        print("  https://www.gyan.dev/ffmpeg/builds/  下载 ffmpeg-release-essentials.zip", file=sys.stderr)
        print("  解压后将 bin 目录加入系统 PATH", file=sys.stderr)
        return 1
    src_dir = os.path.dirname(os.path.abspath(ffmpeg))
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    shutil.copytree(src_dir, dest)
    names = os.listdir(dest)
    print("已复制 %d 个文件到 vendor/ffmpeg-win" % len(names))
    for required in ("ffmpeg.exe", "ffprobe.exe"):
        if required not in names:
            print("[警告] 缺少 %s，预览可能不可用" % required)
    print("来源目录:", src_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
