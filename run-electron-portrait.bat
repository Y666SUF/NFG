@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG Crash - Portrait Electron Launcher

set "NFG_PORTRAIT=1"
call "%~dp0run-electron.bat"

endlocal
exit /b 0
