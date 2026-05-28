@echo off
chcp 65001 >nul
setlocal EnableExtensions

cd /d "%~dp0"
call "%~dp0_paths.bat"
set "PY=%PDFTOOL_PY%"

echo === PDFTool Windows 打包 ===

if not exist "%PY%" (
  echo 未找到 Python 环境：
  echo   %PY%
  echo.
  echo 请先双击运行：安装Python环境.bat
  pause
  exit /b 1
)

"%PY%" -c "import tkinter" >nul 2>&1
if errorlevel 1 (
  echo [错误] 当前 Python 未包含 tkinter，请重新运行：安装Python环境.bat
  pause
  exit /b 1
)

echo 使用 Python：%PY%
"%PY%" -m pip install -U pip
"%PY%" -m pip install -r "%PDFTOOL_ROOT%\requirements.txt"

if errorlevel 1 (
  echo [错误] 依赖安装失败，请检查网络
  pause
  exit /b 1
)

echo.
echo 开始打包单文件 exe ...
"%PY%" -m PyInstaller --noconfirm --clean "%PDFTOOL_ROOT%\PDFTool.spec"

if errorlevel 1 (
  echo 打包失败
  pause
  exit /b 1
)

if not exist "%PDFTOOL_ROOT%\dist\PDFTool.exe" (
  echo 未找到 dist\PDFTool.exe
  pause
  exit /b 1
)

echo.
echo 成功：%PDFTOOL_ROOT%\dist\PDFTool.exe
for %%A in ("%PDFTOOL_ROOT%\dist\PDFTool.exe") do echo 大小：%%~zA 字节
echo.
echo 功能：Word转PDF / 文字·图片水印 / PDF压缩 / 合并 / 拆分
echo Word 转 PDF 需本机安装 LibreOffice（推荐）或 Microsoft Word
echo LibreOffice: https://www.libreoffice.org/download/
echo.
echo 可将 dist\PDFTool.exe 单独拷贝到任意目录双击运行

if "%~1" neq "silent" pause
