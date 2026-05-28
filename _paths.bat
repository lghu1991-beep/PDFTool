@echo off
REM 统一解析 PDFTool 根目录与内置 Python 路径
set "PDFTOOL_ROOT=%~dp0"
if "%PDFTOOL_ROOT:~-1%"=="\" set "PDFTOOL_ROOT=%PDFTOOL_ROOT:~0,-1%"
set "PDFTOOL_PY=%PDFTOOL_ROOT%\runtime\python311\python.exe"
exit /b 0
