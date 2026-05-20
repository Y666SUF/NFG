@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG Platform - Crash + Hangman + Cloudflare

rem --- Shared NFG platform (Node, port 3847) + Hangman (Python, port 19876, proxied on 3847) ---
set "PORT=3847"
set "HOST=0.0.0.0"
set "HANGMAN_PORT=19876"
set "HANGMAN_HOST=127.0.0.1"
set "HANGMAN_BACKEND_URL=http://127.0.0.1:19876"
set "NFG_PLATFORM_URL=http://127.0.0.1:3847"
set "NFG_INTERNAL_SECRET=nfg-dev-internal"
set "NFG_START_HANGMAN=1"
if "%HANGMAN_PYTHON%"=="" set "HANGMAN_PYTHON=py"

set "NFG_CF_TUNNEL=1"
if "%NFG_CF_TUNNEL_NAME%"=="" set "NFG_CF_TUNNEL_NAME=NFG Crash"
set "NFG_CF_TOKEN_FILE=%USERPROFILE%\.nfg-crash-cloudflare-token.cmd"
set "NFG_WEBSITE_FRONTEND_DIR=%~dp0_import_Y666SUF_website\frontend"

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

echo Starting NFG Platform ^(Crash + Hangman^) with Cloudflare tunnel "%NFG_CF_TUNNEL_NAME%"...
if not "%NFG_CF_TUNNEL_TOKEN%"=="" (
  echo Tunnel auth mode: token
) else (
  echo Tunnel auth mode: named tunnel ^(requires cloudflared login/cert^)
  if not exist "%USERPROFILE%\.cloudflared\cert.pem" (
    echo.
    echo WARNING: cert.pem not found at:
    echo   %USERPROFILE%\.cloudflared\cert.pem
    echo.
    echo Fix either by running once:
    echo   cloudflared tunnel login
    echo.
    echo Or set a tunnel token before launch:
    echo   set "NFG_CF_TUNNEL_TOKEN=YOUR_TOKEN_HERE"
    echo.
  )
)
echo.
echo Platform server: port %PORT% ^(Crash + website + shared app chat^)
echo Hangman backend: port %HANGMAN_PORT% ^(auto-started by Node unless NFG_START_HANGMAN=0^)
echo   Proxied on %PORT%: /hangman/ws  and  /api/hangman/*
echo.
echo Website / Cloudflare tunnel ^(single public origin^):
echo   Public: https://y666suf.com
echo   Crash stream: http://127.0.0.1:%PORT%/
echo   Hangman WS ^(apps^): wss://y666suf.com/hangman/ws
echo   Shared chat API: https://y666suf.com/api/mobile/chat
echo   Platform status: https://y666suf.com/api/mobile/platform/status
echo   Local pages: http://127.0.0.1:%PORT%/games/nfg-crash
echo   Crash IPA: https://y666suf.com/download/nfg-crash.ipa
echo.
where %HANGMAN_PYTHON% >nul 2>&1
if errorlevel 1 (
  echo WARNING: Python ^(%HANGMAN_PYTHON%^) not found — Hangman will not start.
  echo Install Python 3 and ensure `py` works, or set HANGMAN_PYTHON=full\path\to\python.exe
  echo.
) else (
  if not exist "%~dp0hangman v2\server.py" (
    echo WARNING: hangman v2\server.py not found — Hangman disabled.
    set "NFG_START_HANGMAN=0"
  ) else (
    echo Hangman folder: %~dp0hangman v2
  )
  echo.
)
set "NFG_IPA_FILE=%USERPROFILE%\Downloads\NFG-Crash.ipa"
set "NFG_HANGMAN_IPA_FILE=%USERPROFILE%\Downloads\NFG-Hangman.ipa"
if exist "%NFG_IPA_FILE%" (echo Crash IPA: %NFG_IPA_FILE%) else (echo Crash IPA: scan Downloads for NFG-Crash.ipa)
if exist "%NFG_HANGMAN_IPA_FILE%" (echo Hangman IPA: %NFG_HANGMAN_IPA_FILE%) else (echo Hangman IPA: scan Downloads for NFG-Hangman.ipa)
echo   Public: https://y666suf.com/download/nfg-hangman.ipa
echo.
if /I not "%NFG_BUILD_WEBSITE%"=="0" (
  if exist "%NFG_WEBSITE_FRONTEND_DIR%\package.json" (
    echo Building React website for port 3847 ...
    pushd "%NFG_WEBSITE_FRONTEND_DIR%"
    set "REACT_APP_BACKEND_URL="
    call corepack yarn build
    if errorlevel 1 (
      echo.
      echo Website build failed. Public domain may show the legacy site until build succeeds.
      echo.
    )
    popd
  )
)
call "%~dp0run-electron.bat"

endlocal
exit /b %errorlevel%
