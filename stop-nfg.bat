@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG - Stop all processes

echo Stopping NFG Crash + Hangman + tunnel...
echo Close any looping run-electron-cloudflare.bat windows first if you can.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\kill-nfg-processes.ps1" -Ports 3847,19876 -KillElectron -KillCloudflared -KillNodeNfg -RepoRoot "%~dp0"
timeout /t 3 /nobreak >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\kill-nfg-processes.ps1" -Ports 3847,19876 -KillElectron -KillCloudflared -KillNodeNfg -RepoRoot "%~dp0" -Quiet
echo.
echo Done. Ports 3847 and 19876 should be free.
echo To start again: run-electron-cloudflare.bat
echo.
pause
endlocal
