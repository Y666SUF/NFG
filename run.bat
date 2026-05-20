@echo off
cd /d "%~dp0"
if exist "%~dp0run-electron.bat" (
  call "%~dp0run-electron.bat"
) else (
  echo run-electron.bat is missing in:
  echo   %~dp0
  echo.
  pause
  exit /b 1
)
