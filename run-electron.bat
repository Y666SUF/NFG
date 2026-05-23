@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG Crash - Electron Launcher

chcp 65001 >nul 2>&1

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
if not defined HANGMAN_PORT set "HANGMAN_PORT=19876"
if not defined HANGMAN_HOST set "HANGMAN_HOST=127.0.0.1"
if not defined HANGMAN_BACKEND_URL set "HANGMAN_BACKEND_URL=http://127.0.0.1:%HANGMAN_PORT%"
if not defined NFG_PLATFORM_URL set "NFG_PLATFORM_URL=http://127.0.0.1:%PORT%"
if not defined NFG_INTERNAL_SECRET set "NFG_INTERNAL_SECRET=nfg-dev-internal"
if not defined NFG_CHAT_ADMIN_USERS set "NFG_CHAT_ADMIN_USERS=y666.suf"
if not defined NFG_START_HANGMAN set "NFG_START_HANGMAN=1"
if not defined HANGMAN_PYTHON set "HANGMAN_PYTHON=py"
if not defined NFG_HANGMAN_GUESS_TIMEOUT_MS set "NFG_HANGMAN_GUESS_TIMEOUT_MS=12000"

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

echo Platform port %PORT% ^| Hangman %HANGMAN_PORT% proxied on %PORT% ^| Hangman start: %NFG_START_HANGMAN%
echo Mobile: GET /api/mobile/hangman/state  POST /api/mobile/hangman/guess  WS /hangman/ws
set "PATH=%~dp0node_modules\.bin;%PATH%"
echo Launching Electron ^(Crash + Hangman windows, shared Node server^)...
echo.
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
