@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG Crash - Electron Launcher

echo NFG Crash - starting desktop app...
echo.

set "NODE_EXE="
set "NPM_CMD="

where node >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%I in ('where node 2^>nul') do (
    call :validate_node "%%I"
    if not errorlevel 1 goto :have_node
  )
)

for /f "delims=" %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0find-node.ps1" 2^>nul') do (
  call :validate_node "%%I"
  if not errorlevel 1 goto :have_node
)

echo Node.js was not found.
echo.
echo Option A - Install ^(recommended^)
echo   Download LTS from https://nodejs.org/ and run the installer.
echo   Enable "Add to PATH", then sign out of Windows and sign back in.
echo.
echo Option B - Portable ^(no admin / no PATH^)
echo   1. Download "Windows Binary (.zip)" for LTS from https://nodejs.org/
echo   2. Extract the ZIP so this file exists:
echo        tools\node\node.exe   ^(inside this same folder^)
echo   3. Run run-electron.bat again.
echo.
pause
exit /b 1

:have_node
for %%F in ("%NODE_EXE%") do set "NODE_DIR=%%~dpF"
set "NODE_DIR=%NODE_DIR:~0,-1%"
set "PATH=%NODE_DIR%;%PATH%"
set "NFG_NODE_EXE=%NODE_EXE%"
if not defined PORT set "PORT=3847"
if not defined HOST set "HOST=0.0.0.0"
set "MAX_BET=unlimited"
rem Optional env: BALANCE_SHOUT_COOLDOWN_MS, TIKTOK_SEND_BALANCE_REPLY
if not defined BALANCE_SHOUT_COOLDOWN_MS set "BALANCE_SHOUT_COOLDOWN_MS=0"
if not defined TIKTOK_SEND_BALANCE_REPLY set "TIKTOK_SEND_BALANCE_REPLY=0"
if not defined HANGMAN_PORT set "HANGMAN_PORT=19876"
if not defined HANGMAN_HOST set "HANGMAN_HOST=127.0.0.1"
if not defined HANGMAN_BACKEND_URL set "HANGMAN_BACKEND_URL=http://127.0.0.1:%HANGMAN_PORT%"
if not defined WORD_GAMES_PORT set "WORD_GAMES_PORT=19877"
if not defined WORD_GAMES_HOST set "WORD_GAMES_HOST=127.0.0.1"
if not defined WORD_GAMES_BACKEND_URL set "WORD_GAMES_BACKEND_URL=http://127.0.0.1:%WORD_GAMES_PORT%"
if not defined NFG_START_WORD_GAMES set "NFG_START_WORD_GAMES=1"
if not defined WORD_GAMES_PYTHON set "WORD_GAMES_PYTHON=%HANGMAN_PYTHON%"
if not defined NFG_PLATFORM_URL set "NFG_PLATFORM_URL=http://127.0.0.1:%PORT%"
if not defined NFG_INTERNAL_SECRET set "NFG_INTERNAL_SECRET=nfg-dev-internal"
if not defined NFG_CHAT_ADMIN_USERS set "NFG_CHAT_ADMIN_USERS=y666.suf"
if not defined NFG_START_HANGMAN set "NFG_START_HANGMAN=1"
if not defined HANGMAN_PYTHON set "HANGMAN_PYTHON=py"
if not defined NFG_HANGMAN_GUESS_TIMEOUT_MS set "NFG_HANGMAN_GUESS_TIMEOUT_MS=12000"
rem Auto-restart OFF by default. Set NFG_AUTO_RESTART=1 to re-enable after crashes.
if not defined NFG_AUTO_RESTART set "NFG_AUTO_RESTART=0"
if not defined NFG_AUTO_RESTART_DELAY_SECONDS set "NFG_AUTO_RESTART_DELAY_SECONDS=8"
if not defined NFG_AUTO_RESTART_MAX_RETRIES set "NFG_AUTO_RESTART_MAX_RETRIES=10"
if not defined NFG_EXIT_ON_FATAL set "NFG_EXIT_ON_FATAL=0"
if not defined LIVE_SONG_COMMAND set "LIVE_SONG_COMMAND=1"
set /a NFG_RESTART_COUNT=0

echo Using Node: %NODE_EXE%
echo.

if not exist "node_modules\" (
  echo First run: installing dependencies...
  call "%NPM_CMD%" install --include=dev
  if errorlevel 1 (
    echo.
    echo npm install failed.
    pause
    exit /b 1
  )
  echo.
)

echo Platform port %PORT% ^| Hangman %HANGMAN_PORT% proxied on %PORT% ^| Word Games %WORD_GAMES_PORT% proxied on %PORT%
echo Mobile Hangman: GET /api/mobile/hangman/state  POST /api/mobile/hangman/guess  WS /hangman/ws
echo Mobile Words:  GET https://y666suf.com/api/word-games/health  POST /api/word-games/players/login
set "PATH=%~dp0node_modules\.bin;%PATH%"
echo Clearing stale listeners on %PORT% / %HANGMAN_PORT% before launch...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\kill-nfg-processes.ps1" -Ports %PORT%,%HANGMAN_PORT% -KillElectron -KillNodeNfg -RepoRoot "%~dp0" -Quiet
echo Launching Electron ^(Crash + Hangman windows, shared Node server^)...
echo.
if "%NFG_AUTO_RESTART%"=="0" (
  call "%NPM_CMD%" run start:electron
  if errorlevel 1 (
    echo.
    echo Electron failed to start.
    echo Run this in PowerShell for details:
    echo   cd /d "%~dp0"
    echo   npm run start:electron
    echo.
    pause
    exit /b 1
  )
) else (
:restart_electron
  call "%NPM_CMD%" run start:electron
  set "NFG_LAST_EXIT=%errorlevel%"
  if "%NFG_LAST_EXIT%"=="0" goto :electron_ok
  set /a NFG_RESTART_COUNT+=1
  echo.
  echo Electron exited unexpectedly ^(code %NFG_LAST_EXIT%^).
  if "%NFG_LAST_EXIT%"=="3221226505" (
    echo Detected Windows app-crash code 3221226505 ^(0xC0000409^). Restarting automatically...
  )
  if "%NFG_AUTO_RESTART_MAX_RETRIES%"=="0" (
    echo WARNING: NFG_AUTO_RESTART_MAX_RETRIES=0 means UNLIMITED restarts.
    echo Set NFG_AUTO_RESTART=0 or NFG_AUTO_RESTART_MAX_RETRIES=10 to stop the loop.
  ) else if %NFG_RESTART_COUNT% GEQ %NFG_AUTO_RESTART_MAX_RETRIES% (
    echo Reached max auto-restart retries ^(%NFG_AUTO_RESTART_MAX_RETRIES%^).
    goto :electron_failed
  )
  echo Clearing stale NFG processes before auto-restart...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\kill-nfg-processes.ps1" -Ports %PORT%,%HANGMAN_PORT% -KillElectron -KillNodeNfg -RepoRoot "%~dp0" -Quiet
  timeout /t 3 /nobreak >nul
  cls
  echo Auto-restart attempt %NFG_RESTART_COUNT% / %NFG_AUTO_RESTART_MAX_RETRIES% in %NFG_AUTO_RESTART_DELAY_SECONDS%s...
  timeout /t %NFG_AUTO_RESTART_DELAY_SECONDS% /nobreak >nul
  goto :restart_electron
)

:electron_ok
goto :done

:electron_failed
echo.
echo Electron failed to start.
echo Run this in PowerShell for details:
echo   cd /d "%~dp0"
echo   npm run start:electron
echo.
pause
exit /b 1

:done
endlocal
exit /b 0

:validate_node
set "CAND_NODE=%~1"
if "%CAND_NODE%"=="" exit /b 1
if not exist "%CAND_NODE%" exit /b 1

for %%F in ("%CAND_NODE%") do set "CAND_DIR=%%~dpF"
set "CAND_DIR=%CAND_DIR:~0,-1%"
if exist "%CAND_DIR%\npm.cmd" (
  set "NODE_EXE=%CAND_NODE%"
  set "NPM_CMD=%CAND_DIR%\npm.cmd"
  exit /b 0
)

exit /b 1
