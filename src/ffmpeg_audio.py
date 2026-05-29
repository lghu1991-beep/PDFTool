# -*- coding: utf-8 -*-
"""Windows / 跨平台 ffmpeg 调用（优先使用打包内置）。"""

from __future__ import annotations

import os
import subprocess
import sys
from typing import List, Optional, Tuple

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".avi", ".webm", ".m4v", ".flv", ".wmv"}
AUDIO_EXTS = {".mp3", ".m4a", ".wav", ".aac", ".flac", ".aiff", ".caf", ".ogg", ".wma"}


def _bundled_ffmpeg_dir() -> str:
    if getattr(sys, "frozen", False):
        return os.path.join(getattr(sys, "_MEIPASS", ""), "ffmpeg")
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(root, "vendor", "ffmpeg-win")


def _tool_path(name: str) -> Optional[str]:
    if sys.platform == "win32":
        exe = name if name.lower().endswith(".exe") else name + ".exe"
    else:
        exe = name.replace(".exe", "")
    bundled = os.path.join(_bundled_ffmpeg_dir(), exe)
    if os.path.isfile(bundled):
        return bundled
    import shutil

    return shutil.which(exe.replace(".exe", "")) or shutil.which(exe)


def is_available() -> bool:
    return _tool_path("ffmpeg") is not None and _tool_path("ffprobe") is not None


def availability_hint() -> str:
    if os.path.isdir(_bundled_ffmpeg_dir()):
        return "未找到内置 ffmpeg，请重新运行 build.bat 打包。"
    if sys.platform == "win32":
        return "未找到 ffmpeg。打包请安装 ffmpeg 并加入 PATH；或从 https://www.gyan.dev/ffmpeg/builds/ 下载。"
    return "未找到 ffmpeg。请安装：brew install ffmpeg"


def _creationflags() -> int:
    if sys.platform == "win32":
        return getattr(subprocess, "CREATE_NO_WINDOW", 0)
    return 0


def _run(args: List[str]) -> Tuple[bool, str, str]:
    try:
        proc = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            creationflags=_creationflags(),
            cwd=os.path.dirname(args[0]) if args and os.path.isfile(args[0]) else None,
        )
        ok = proc.returncode == 0
        return ok, proc.stdout or "", proc.stderr or ""
    except Exception as exc:  # noqa: BLE001
        return False, "", str(exc)


def _codec_args(fmt: str) -> List[str]:
    fmt = fmt.lower().lstrip(".")
    if fmt == "wav":
        return ["-acodec", "pcm_s16le"]
    if fmt in ("m4a", "aac"):
        return ["-acodec", "aac", "-b:a", "192k"]
    return ["-acodec", "libmp3lame", "-q:a", "2"]


def probe_duration(path: str) -> float:
    ffprobe = _tool_path("ffprobe")
    if not ffprobe:
        raise RuntimeError(availability_hint())
    ok, out, err = _run(
        [
            ffprobe,
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            path,
        ]
    )
    if not ok:
        raise RuntimeError(err or out or "无法读取时长")
    try:
        return max(0.0, float(out.strip()))
    except ValueError as exc:
        raise RuntimeError("时长解析失败") from exc


def extract_from_video(video_path: str, output_path: str, fmt: str = "mp3") -> str:
    ffmpeg = _tool_path("ffmpeg")
    if not ffmpeg:
        raise RuntimeError(availability_hint())
    args = [ffmpeg, "-y", "-i", video_path, "-vn"] + _codec_args(fmt) + [output_path]
    ok, out, err = _run(args)
    if not ok or not os.path.isfile(output_path):
        raise RuntimeError(err or out or "提取音频失败")
    return output_path


def trim_audio(input_path: str, output_path: str, start: str, end: str) -> str:
    ffmpeg = _tool_path("ffmpeg")
    if not ffmpeg:
        raise RuntimeError(availability_hint())
    ext = os.path.splitext(output_path)[1].lstrip(".") or "mp3"
    args = [ffmpeg, "-y", "-i", input_path, "-ss", start, "-to", end, "-vn"] + _codec_args(ext) + [output_path]
    ok, out, err = _run(args)
    if not ok or not os.path.isfile(output_path):
        raise RuntimeError(err or out or "剪辑失败")
    return output_path


def export_audio(input_path: str, output_path: str, fmt: str) -> str:
    ffmpeg = _tool_path("ffmpeg")
    if not ffmpeg:
        raise RuntimeError(availability_hint())
    args = [ffmpeg, "-y", "-i", input_path, "-vn"] + _codec_args(fmt) + [output_path]
    ok, out, err = _run(args)
    if not ok or not os.path.isfile(output_path):
        raise RuntimeError(err or out or "导出失败")
    return output_path


def play_preview(path: str) -> None:
    """使用 ffplay 预览（若已打包）。"""
    ffplay = _tool_path("ffplay")
    if not ffplay:
        raise RuntimeError("未找到 ffplay，无法预览。")
    subprocess.Popen(
        [ffplay, "-nodisp", "-autoexit", path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=_creationflags(),
        cwd=os.path.dirname(ffplay),
    )


def format_time(seconds: float) -> str:
    if seconds < 0 or seconds != seconds:  # NaN
        seconds = 0.0
    total_cs = int(round(seconds * 100.0))
    cs = total_cs % 100
    total_sec = total_cs // 100
    s = total_sec % 60
    m = (total_sec // 60) % 60
    h = total_sec // 3600
    if h > 0:
        return "%02d:%02d:%02d.%02d" % (h, m, s, cs)
    return "%02d:%02d.%02d" % (m, s, cs)


def is_video(path: str) -> bool:
    return os.path.splitext(path)[1].lower() in VIDEO_EXTS
