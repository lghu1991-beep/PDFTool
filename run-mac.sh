#!/bin/bash
cd "$(dirname "$0")"
if [ -d "dist/PDFTool.app" ]; then
  open "dist/PDFTool.app"
elif [ -f "dist/PDFTool/PDFTool" ]; then
  "dist/PDFTool/PDFTool"
else
  python3 src/main.py
fi
