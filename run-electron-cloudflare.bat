@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG Platform - Crash + Hangman + Cloudflare

rem =============================================================================
rem NFG Platform launcher (Crash + Hangman + public tunnel)
rem   Node platform     : PORT 3847  (Crash, website, mobile APIs, IPA downloads)
rem   Hangman Python    : HANGMAN_PORT 19876  (FastAPI in hangman v2\)
rem   Hangman proxied   : /hangman/ws  and  /api/hangman/*  on 3847
rem   iOS Hangman app   : polls GET /api/mobile/hangman/state every 2s
rem                       guesses POST /api/mobile/hangman/guess
rem   Public origin     : https://y666suf.com  (Cloudflare tunnel)
rem Pull latest from GitHub before live streams so mobile + desktop stay in sync.
rem =============================================================================

set "PORT=3847"
set "HOST=0.0.0.0"
set "HANGMAN_PORT=19876"
set "HANGMAN_HOST=127.0.0.1"
set "HANGMAN_BACKEND_URL=http://127.0.0.1:19876"
set "NFG_PLATFORM_URL=http://127.0.0.1:3847"
set "NFG_INTERNAL_SECRET=nfg-dev-internal"
set "NFG_START_HANGMAN=1"
set "NFG_HANGMAN_GUESS_TIMEOUT_MS=12000"
if "%HANGMAN_PYTHON%"=="" set "HANGMAN_PYTHON=py"

set "NFG_CF_TUNNEL=1"
if "%NFG_CF_TUNNEL_NAME%"=="" set "NFG_CF_TUNNEL_NAME=NFG Crash"
set "NFG_CF_TOKEN_FILE=%USERPROFILE%\.nfg-crash-cloudflare-token.cmd"
set "NFG_WEBSITE_FRONTEND_DIR=%~dp0_import_Y666SUF_website\frontend"

rem --- IPA paths: repo releases\ipa first (served by Node), then Downloads ---
if exist "%~dp0releases\ipa\NFG-Crash.ipa" (
  set "NFG_IPA_FILE=%~dp0releases\ipa\NFG-Crash.ipa"
) else (
  set "NFG_IPA_FILE=%USERPROFILE%\Downloads\NFG-Crash.ipa"
)
if exist "%~dp0releases\ipa\NFG-Hangman.ipa" (
  set "NFG_HANGMAN_IPA_FILE=%~dp0releases\ipa\NFG-Hangman.ipa"
) else (
  set "NFG_HANGMAN_IPA_FILE=%USERPROFILE%\Downloads\NFG-Hangman.ipa"
)

if "%NFG_CF_TUNNEL_TOKEN%"=="" (
  if exist "%NFG_CF_TOKEN_FILE%" call "%NFG_CF_TOKEN_FILE%"
)

if not "%NFG_CF_TUNNEL_TOKEN%"=="" (
  if /I "%NFG_CF_TUNNEL_TOKEN:~0,4%"=="set " (
    echo Invalid saved tunnel token detected ^(looks like a command^).
    echo Run set-cloudflare-token.bat and paste only the long token value.
    set "NFG_CF_TUNNEL_TOKEN="
  )
)

if "%NFG_CF_TUNNEL_TOKEN%"=="" (
  for /f "delims=" %%I in ('cloudflared tunnel token "%NFG_CF_TUNNEL_NAME%" 2^>nul') do (
    set "NFG_CF_TUNNEL_TOKEN=%%I"
  )
)
if not "%NFG_CF_TUNNEL_TOKEN%"=="" (
  if not "%NFG_CF_TUNNEL_TOKEN%"=="%NFG_CF_TUNNEL_TOKEN: =%" (
    set "NFG_CF_TUNNEL_TOKEN="
  )
)
if not "%NFG_CF_TUNNEL_TOKEN%"=="" (
  if "%NFG_CF_TUNNEL_TOKEN:~60,1%"=="" (
    set "NFG_CF_TUNNEL_TOKEN="
  )
)
if not "%NFG_CF_TUNNEL_TOKEN%"=="" (
  > "%NFG_CF_TOKEN_FILE%" echo @echo off
  >> "%NFG_CF_TOKEN_FILE%" echo set "NFG_CF_TUNNEL_TOKEN=%NFG_CF_TUNNEL_TOKEN%"
)

if not "%NFG_CLOUDFLARED_EXE%"=="" (
  if not exist "%NFG_CLOUDFLARED_EXE%" (
    echo NFG_CLOUDFLARED_EXE is set but file was not found:
    echo   %NFG_CLOUDFLARED_EXE%
    echo.
    pause
    exit /b 1
  )
) else (
  where cloudflared >nul 2>&1
  if errorlevel 1 (
    echo cloudflared was not found in PATH.
    echo.
    echo Install cloudflared or set NFG_CLOUDFLARED_EXE before launching.
    echo Example:
    echo   set "NFG_CLOUDFLARED_EXE=C:\Program Files\cloudflared\cloudflared.exe"
    echo.
    pause
    exit /b 1
  )
)

echo.
echo ============================================================
echo  NFG Platform - Crash + Hangman + Cloudflare
echo ============================================================
echo   Electron: NFG Crash, Player Lookup, App Chat, NFG Hangman
echo   Tunnel: "%NFG_CF_TUNNEL_NAME%"
if not "%NFG_CF_TUNNEL_TOKEN%"=="" (
  echo   Tunnel auth: token
) else (
  echo   Tunnel auth: named tunnel ^(cloudflared login/cert^)
  if not exist "%USERPROFILE%\.cloudflared\cert.pem" (
    echo.
    echo WARNING: cert.pem not found. Run once: cloudflared tunnel login
    echo.
  )
)
echo.
echo --- Ports ---
echo   Platform Node:     %PORT%  ^(0.0.0.0^)
echo   Hangman Python:    %HANGMAN_PORT%  ^(auto-start unless NFG_START_HANGMAN=0^)
echo   Hangman backend:   %HANGMAN_BACKEND_URL%
echo.
echo --- Public ^(https://y666suf.com^) ---
echo   Website / sideload:  https://y666suf.com/sideload
echo   Crash stream:        http://127.0.0.1:%PORT%/
echo   Hangman desktop UI:  http://127.0.0.1:%HANGMAN_PORT%/
echo.
echo --- Hangman mobile companion ^(NFG Hangman iOS^) ---
echo   WebSocket:   wss://y666suf.com/hangman/ws
echo   State poll:  GET  https://y666suf.com/api/mobile/hangman/state
echo   App guess:   POST https://y666suf.com/api/mobile/hangman/guess
echo   Link/chat:   /api/mobile/link/*  /api/mobile/chat
echo   Python API:  GET  /api/hangman/app/state  ^(proxied on %PORT%^)
echo.
echo --- Shared APIs ---
echo   App chat:    https://y666suf.com/api/mobile/chat
echo   Presence:    https://y666suf.com/api/mobile/platform/status
echo   Crash IPA:   https://y666suf.com/download/nfg-crash.ipa
echo   Hangman IPA: https://y666suf.com/download/nfg-hangman.ipa
echo.
where %HANGMAN_PYTHON% >nul 2>&1
if errorlevel 1 (
  echo WARNING: Python ^(%HANGMAN_PYTHON%^) not found - Hangman will not start.
  echo   Install Python 3 or set HANGMAN_PYTHON=full\path\to\python.exe
  echo.
) else (
  if not exist "%~dp0hangman v2\server.py" (
    echo WARNING: hangman v2\server.py not found - Hangman disabled.
    set "NFG_START_HANGMAN=0"
  ) else (
    echo Hangman source: %~dp0hangman v2
  )
  echo.
)
if exist "%NFG_IPA_FILE%" (
  echo Crash IPA:   %NFG_IPA_FILE%
) else (
  echo Crash IPA:   not found - run git pull for releases\ipa\NFG-Crash.ipa
)
if exist "%NFG_HANGMAN_IPA_FILE%" (
  echo Hangman IPA: %NFG_HANGMAN_IPA_FILE%
) else (
  echo Hangman IPA: not found - run git pull for releases\ipa\NFG-Hangman.ipa
)
echo.
if /I not "%NFG_BUILD_WEBSITE%"=="0" (
  if exist "%NFG_WEBSITE_FRONTEND_DIR%\package.json" (
    echo Building React website for port %PORT% ...
    pushd "%NFG_WEBSITE_FRONTEND_DIR%"
    set "REACT_APP_BACKEND_URL="
    call corepack yarn build
    if errorlevel 1 (
      echo.
      echo Website build failed. Public domain may show legacy site until build succeeds.
      echo.
    )
    popd
  )
)
echo Starting Electron + Node + Hangman + tunnel...
echo.
call "%~dp0run-electron.bat"

endlocal
exit /b %errorlevel%
