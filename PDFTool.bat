@echo off
chcp 65001 >nul
title PDFTool
cd /d "%~dp0"

if exist "dist\PDFTool.exe" (
  start "" "dist\PDFTool.exe"
  exit /b 0
)

echo ========================================
echo   PDFTool 首次运行
echo ========================================
echo.
echo 正在自动安装环境并生成独立程序，约 3~5 分钟。
echo 请保持网络畅通，请勿关闭本窗口。
echo.

call "%~dp0安装并打包.bat" silent

if exist "dist\PDFTool.exe" (
  echo.
  echo 生成完成，正在启动 PDFTool ...
  start "" "dist\PDFTool.exe"
  exit /b 0
)

echo.
echo [错误] 未能生成 PDFTool.exe
echo 请双击「检查环境.bat」查看原因，或阅读「从压缩包到exe完整步骤.txt」
pause
