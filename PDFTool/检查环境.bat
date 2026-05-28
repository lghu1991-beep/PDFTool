@echo off
chcp 65001 >nul
title PDFTool - 检查环境
setlocal EnableExtensions

cd /d "%~dp0"
call "%~dp0_paths.bat"

echo ========================================
echo   PDFTool 环境检查
echo ========================================
echo.
echo 项目目录：%PDFTOOL_ROOT%
echo Python 路径：%PDFTOOL_PY%
echo.

if exist "%PDFTOOL_PY%" (
  echo [OK] 找到 python.exe
  "%PDFTOOL_PY%" --version
  "%PDFTOOL_PY%" -c "import tkinter; print('[OK] tkinter 可用')"
) else (
  echo [缺失] 未找到 python.exe
  echo 请双击运行：安装Python环境.bat
)

if exist "%PDFTOOL_ROOT%\runtime\python-3.11.9-amd64.exe" (
  echo [OK] 找到 Python 安装包
) else (
  echo [缺失] runtime\python-3.11.9-amd64.exe
)

if exist "%PDFTOOL_ROOT%\dist\PDFTool.exe" (
  echo [OK] 已生成 dist\PDFTool.exe
) else (
  echo [提示] 尚未打包 exe，可运行：安装并打包.bat
)

echo.
pause
