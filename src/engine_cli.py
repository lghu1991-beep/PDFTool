# -*- coding: utf-8 -*-
"""PDFTool 无界面引擎：供 macOS 原生应用通过子进程调用。"""

from __future__ import annotations

import argparse
import json
import os
import sys
import traceback
from typing import Any, Dict, List, Tuple

_BASE = os.path.dirname(os.path.abspath(__file__))
if _BASE not in sys.path:
    sys.path.insert(0, _BASE)

try:
    from pdf_core import (  # noqa: E402
        add_image_watermark,
        add_text_watermark,
        compress_pdf,
        merge_pdfs,
        pdf_page_count,
        split_every_page,
        split_pdf,
    )
    from word_convert import word_to_pdf  # noqa: E402
except Exception as exc:  # noqa: BLE001
    _IMPORT_ERROR = exc
else:
    _IMPORT_ERROR = None


def _emit(ok: bool, data: Any = None, error: str = "") -> None:
    payload: Dict[str, Any] = {"ok": ok}
    if ok:
        payload["data"] = data if data is not None else {}
    else:
        payload["error"] = error or "unknown error"
    sys.stdout.write(json.dumps(payload, ensure_ascii=False))
    sys.stdout.write("\n")
    sys.stdout.flush()


def _fail(message: str) -> None:
    _emit(False, error=message)
    sys.exit(1)


def _parse_ranges(text: str) -> List[Tuple[int, int]]:
    ranges: List[Tuple[int, int]] = []
    for part in text.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-", 1)
            start, end = int(a.strip()), int(b.strip())
        else:
            start = end = int(part)
        ranges.append((start, end))
    if not ranges:
        raise ValueError("页码范围不能为空")
    return ranges


def cmd_word(args: argparse.Namespace) -> Any:
    out = word_to_pdf(args.input, args.output)
    return {"path": out}


def cmd_watermark_text(args: argparse.Namespace) -> Any:
    add_text_watermark(
        args.input,
        args.output,
        args.text,
        opacity=args.opacity,
        angle=args.angle,
        font_size=args.font_size,
        position=args.position,
        layout=args.layout,
    )
    return {"path": args.output}


def cmd_watermark_image(args: argparse.Namespace) -> Any:
    add_image_watermark(
        args.input,
        args.output,
        args.image,
        opacity=args.opacity,
        scale=args.scale,
        angle=args.angle,
        position=args.position,
        layout=args.layout,
    )
    return {"path": args.output}


def cmd_compress(args: argparse.Namespace) -> Any:
    return compress_pdf(args.input, args.output, level=args.level)


def cmd_merge(args: argparse.Namespace) -> Any:
    merge_pdfs(args.inputs, args.output)
    return {"path": args.output, "count": len(args.inputs)}


def cmd_split_range(args: argparse.Namespace) -> Any:
    ranges = _parse_ranges(args.ranges)
    paths = split_pdf(args.input, args.output_dir, ranges)
    return {"paths": paths, "count": len(paths)}


def cmd_split_each(args: argparse.Namespace) -> Any:
    paths = split_every_page(args.input, args.output_dir)
    return {"paths": paths, "count": len(paths)}


def cmd_page_count(args: argparse.Namespace) -> Any:
    return {"count": pdf_page_count(args.input)}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="PDFTool engine")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("word")
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)

    p = sub.add_parser("watermark-text")
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--text", required=True)
    p.add_argument("--opacity", type=float, default=0.25)
    p.add_argument("--angle", type=float, default=45.0)
    p.add_argument("--font-size", type=int, default=48)
    p.add_argument("--position", default="center")
    p.add_argument("--layout", default="single")

    p = sub.add_parser("watermark-image")
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--image", required=True)
    p.add_argument("--opacity", type=float, default=0.35)
    p.add_argument("--scale", type=float, default=0.25)
    p.add_argument("--angle", type=float, default=0.0)
    p.add_argument("--position", default="center")
    p.add_argument("--layout", default="single")

    p = sub.add_parser("compress")
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--level", choices=["light", "medium", "strong"], default="medium")

    p = sub.add_parser("merge")
    p.add_argument("--inputs", nargs="+", required=True)
    p.add_argument("--output", required=True)

    p = sub.add_parser("split-range")
    p.add_argument("--input", required=True)
    p.add_argument("--output-dir", required=True)
    p.add_argument("--ranges", required=True, help="如 1-3,5-8")

    p = sub.add_parser("split-each")
    p.add_argument("--input", required=True)
    p.add_argument("--output-dir", required=True)

    p = sub.add_parser("page-count")
    p.add_argument("--input", required=True)

    return parser


def main() -> None:
    if _IMPORT_ERROR is not None:
        _fail("模块加载失败: %s" % _IMPORT_ERROR)

    parser = build_parser()
    args = parser.parse_args()
    handlers = {
        "word": cmd_word,
        "watermark-text": cmd_watermark_text,
        "watermark-image": cmd_watermark_image,
        "compress": cmd_compress,
        "merge": cmd_merge,
        "split-range": cmd_split_range,
        "split-each": cmd_split_each,
        "page-count": cmd_page_count,
    }
    try:
        data = handlers[args.command](args)
        _emit(True, data=data)
    except Exception as exc:  # noqa: BLE001
        detail = "".join(traceback.format_exception_only(type(exc), exc)).strip()
        _fail(detail)


if __name__ == "__main__":
    main()
