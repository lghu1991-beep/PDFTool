@echo off
chcp 65001 >nul
title PDFTool - 安装 Python 环境
setlocal EnableExtensions

cd /d "%~dp0"
call "%~dp0_paths.bat"
set "ROOT=%PDFTOOL_ROOT%"
set "RUNTIME=%ROOT%\runtime"
set "PYDIR=%RUNTIME%\python311"
set "PY=%PDFTOOL_PY%"
set "INSTALLER=%RUNTIME%\python-3.11.9-amd64.exe"

echo ========================================
echo   PDFTool - 安装本地 Python 3.11 环境
echo ========================================
echo.
echo 项目目录：%ROOT%
echo 安装位置：%PYDIR%
echo.

if exist "%PY%" (
  echo 已检测到 Python 环境，跳过安装。
  "%PY%" --version
  goto :verify
)

if not exist "%INSTALLER%" (
  echo [错误] 找不到安装包：
  echo   %INSTALLER%
  echo 请确认 runtime 目录下有 python-3.11.9-amd64.exe
  pause
  exit /b 1
)

echo 正在安装 Python（约 1 分钟，含 tkinter / pip）...
echo 请勿关闭窗口...
"%INSTALLER%" /passive InstallAllUsers=0 PrependPath=0 SimpleInstall=1 Include_test=0 Include_pip=1 Include_tkinter=1 TargetDir="%PYDIR%"

if not exist "%PY%" (
  echo.
  echo [错误] Python 安装失败，未找到：
  echo   %PY%
  echo.
  echo 请检查是否被杀毒软件拦截，或以管理员身份重试。
  pause
  exit /b 1
)

:verify
echo.
echo 验证 tkinter ...
"%PY%" -c "import tkinter" 2>nul
if errorlevel 1 (
  echo [错误] tkinter 不可用，请重新运行本脚本
  pause
  exit /b 1
)

echo.
echo Python 环境就绪：
"%PY%" --version
echo 程序路径：%PY%
echo.
echo 下一步：双击「PDFTool.bat」或「安装并打包.bat」
echo.
if "%~1" neq "silent" pause
