@echo off
chcp 65001 >nul
cd /d "%~dp0"
call "%~dp0_paths.bat"

if not exist "%PDFTOOL_PY%" (
  echo 请先运行：安装Python环境.bat
  pause
  exit /b 1
)

"%PDFTOOL_PY%" -m pip install -r "%PDFTOOL_ROOT%\requirements.txt" -q
echo 打包调试版（带控制台）...
"%PDFTOOL_PY%" -m PyInstaller --noconfirm --clean "%PDFTOOL_ROOT%\PDFTool-debug.spec"

if exist "%PDFTOOL_ROOT%\dist\PDFTool-debug.exe" (
  echo.
  echo 成功：dist\PDFTool-debug.exe
  echo 在出问题的 Win10 上运行此 exe，把黑色窗口里的报错截图或复制出来。
) else (
  echo 打包失败
)
pause
