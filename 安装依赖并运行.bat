@echo off
chcp 65001 >nul
title PDFTool - 安装依赖并运行
setlocal EnableExtensions

cd /d "%~dp0"
call "%~dp0_paths.bat"
set "PY=%PDFTOOL_PY%"

if not exist "%PY%" (
  echo 未找到 Python 环境，先运行「安装Python环境.bat」...
  call "%~dp0安装Python环境.bat"
  if not exist "%PY%" exit /b 1
)

echo ========================================
echo   PDFTool - 安装依赖并启动
echo ========================================
echo.
echo 使用 Python：%PY%
echo.

"%PY%" -m pip install -U pip
"%PY%" -m pip install -r "%PDFTOOL_ROOT%\requirements.txt"

if errorlevel 1 (
  echo [错误] 依赖安装失败，请检查网络
  pause
  exit /b 1
)

echo.
echo 启动 PDFTool ...
"%PY%" "%PDFTOOL_ROOT%\src\main.py"
