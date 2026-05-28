@echo off
chcp 65001 >nul
<<<<<<< HEAD
title PDFTool 安装并打包
setlocal EnableExtensions

cd /d "%~dp0"
call "%~dp0_paths.bat"

echo ========================================
echo   PDFTool - 一键安装依赖并生成 exe
echo ========================================
echo.

if not exist "%PDFTOOL_PY%" (
  echo 未检测到本地 Python，先安装内置环境...
  call "%~dp0安装Python环境.bat" %1
  if not exist "%PDFTOOL_PY%" exit /b 1
)

call "%~dp0build.bat" %1
=======
title QYPdfTool 安装并打包
cd /d "%~dp0"

echo ========================================
echo   QYPdfTool - 一键安装依赖并生成 exe
echo ========================================
echo.

where python >nul 2>&1
if errorlevel 1 (
  echo [错误] 未找到 Python。
  echo.
  echo 请先安装 Python 3.10 或 3.11：
  echo   https://www.python.org/downloads/windows/
  echo 安装时务必勾选 "Add python.exe to PATH"
  echo 以及 "tcl/tk and IDLE"（Tkinter 界面需要）
  echo.
  pause
  exit /b 1
)

python -c "import tkinter" >nul 2>&1
if errorlevel 1 (
  echo [错误] 当前 Python 未包含 tkinter，请重新安装并勾选 tcl/tk。
  pause
  exit /b 1
)

call build.bat
>>>>>>> ea23488 (chore: QYPdfTool 初始版本，GitHub Actions 自动打包 Windows exe)
