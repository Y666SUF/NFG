@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG Crash - Server Watchdog

if not defined PORT set "PORT=3847"
if not defined NFG_START_HANGMAN set "NFG_START_HANGMAN=0"
if not defined WORD_GAMES_PORT set "WORD_GAMES_PORT=19877"
if not defined NFG_AUTO_RESTART_DELAY_SECONDS set "NFG_AUTO_RESTART_DELAY_SECONDS=5"
if not defined NFG_AUTO_RESTART_MAX_RETRIES set "NFG_AUTO_RESTART_MAX_RETRIES=0"
set /a NFG_RESTART_COUNT=0

echo NFG Crash server watchdog — auto-restart on crash
echo Platform port %PORT% ^| Word Games %WORD_GAMES_PORT%
echo.

:restart_server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\kill-nfg-processes.ps1" -Ports "%PORT%,19876,%WORD_GAMES_PORT%" -Quiet
cls
echo [%date% %time%] Starting node server\index.js ...
node server\index.js
set "NFG_LAST_EXIT=%errorlevel%"
if "%NFG_LAST_EXIT%"=="0" goto :server_ok

set /a NFG_RESTART_COUNT+=1
echo.
echo Server exited with code %NFG_LAST_EXIT%.
if "%NFG_LAST_EXIT%"=="3221226505" (
  echo Detected Windows crash 3221226505 ^(0xC0000409^) — cleaning up and restarting...
)
if not "%NFG_AUTO_RESTART_MAX_RETRIES%"=="0" (
  if %NFG_RESTART_COUNT% GEQ %NFG_AUTO_RESTART_MAX_RETRIES% (
    echo Reached max auto-restart retries ^(%NFG_AUTO_RESTART_MAX_RETRIES%^).
    pause
    exit /b %NFG_LAST_EXIT%
  )
)
echo Auto-restart attempt %NFG_RESTART_COUNT% in %NFG_AUTO_RESTART_DELAY_SECONDS%s...
timeout /t %NFG_AUTO_RESTART_DELAY_SECONDS% /nobreak >nul
goto :restart_server

:server_ok
endlocal
exit /b 0
