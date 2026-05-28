@echo off
chcp 65001 >nul
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
