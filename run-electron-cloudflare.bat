@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG Platform - Crash + Cloudflare

rem =============================================================================
rem NFG Platform launcher (Crash + Word Games + public tunnel)
rem   Node platform     : PORT 3847
rem   Word Games Python : WORD_GAMES_PORT 19877
rem   Hangman           : OFF by default (NFG_START_HANGMAN=0)
rem   Public origin     : https://y666suf.com  (Cloudflare tunnel)
rem Pull latest from GitHub before live streams so mobile + desktop stay in sync.
rem =============================================================================

set "PORT=3847"
set "HOST=0.0.0.0"
set "HANGMAN_PORT=19876"
set "HANGMAN_HOST=127.0.0.1"
set "HANGMAN_BACKEND_URL=http://127.0.0.1:19876"
set "WORD_GAMES_PORT=19877"
set "WORD_GAMES_HOST=127.0.0.1"
set "WORD_GAMES_BACKEND_URL=http://127.0.0.1:19877"
set "NFG_WORD_GAMES_DIR=%USERPROFILE%\Documents\nfg-word-games"
set "WORD_GAMES_DATA_DIR=%USERPROFILE%\Documents\nfg-word-games\data"
set "NFG_START_WORD_GAMES=1"
if "%WORD_GAMES_PYTHON%"=="" set "WORD_GAMES_PYTHON=%HANGMAN_PYTHON%"
set "PIXEL_JUMP_PORT=8001"
set "PIXEL_JUMP_HOST=127.0.0.1"
set "PIXEL_JUMP_BACKEND_URL=http://127.0.0.1:8001"
set "PIXEL_JUMP_DIR=%USERPROFILE%\Documents\NFG-JUMP-MULTIPLAYER"
set "PUBLIC_PATH_PREFIX=/api/pixel-jump"
set "NFG_START_PIXEL_JUMP=1"
set "NFG_PLATFORM_URL=http://127.0.0.1:3847"
set "NFG_INTERNAL_SECRET=nfg-dev-internal"
set "NFG_CHAT_ADMIN_USERS=y666.suf"
set "NFG_START_HANGMAN=0"
set "NFG_OPEN_HANGMAN_WINDOW=0"
set "NFG_OPEN_PLAYER_LOOKUP=0"
set "NFG_HANGMAN_GUESS_TIMEOUT_MS=12000"
set "LIVE_SONG_COMMAND=1"
if "%HANGMAN_PYTHON%"=="" set "HANGMAN_PYTHON=py"
rem Auto-restart OFF by default (prevents infinite loops). Set NFG_AUTO_RESTART=1 to enable.
if not defined NFG_AUTO_RESTART set "NFG_AUTO_RESTART=0"
if not defined NFG_AUTO_RESTART_DELAY_SECONDS set "NFG_AUTO_RESTART_DELAY_SECONDS=8"
if not defined NFG_AUTO_RESTART_MAX_RETRIES set "NFG_AUTO_RESTART_MAX_RETRIES=10"
if not defined NFG_EXIT_ON_FATAL set "NFG_EXIT_ON_FATAL=0"
if not defined NFG_KILL_OLD_SESSIONS set "NFG_KILL_OLD_SESSIONS=1"
if not defined BALANCE_SHOUT_COOLDOWN_MS set "BALANCE_SHOUT_COOLDOWN_MS=0"
if not defined TIKTOK_SEND_BALANCE_REPLY set "TIKTOK_SEND_BALANCE_REPLY=0"

rem --- Stop leftover Electron / Node / Hangman / cloudflared from prior runs ---
if "%NFG_KILL_OLD_SESSIONS%"=="1" (
  echo.
  echo Stopping old NFG sessions ^(ports %PORT% / %WORD_GAMES_PORT%, Electron, cloudflared^)...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\kill-nfg-processes.ps1" -Ports "%PORT%,19876,%WORD_GAMES_PORT%,8001" -KillElectron -KillCloudflared -KillNodeNfg -RepoRoot "%~dp0" -Quiet
  timeout /t 2 /nobreak >nul
  echo Ready for fresh launch.
  echo.
)

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
echo  NFG Platform - Crash + Cloudflare
echo ============================================================
echo   Kill old sessions on start: %NFG_KILL_OLD_SESSIONS%
echo   Auto-restart: %NFG_AUTO_RESTART% ^(delay %NFG_AUTO_RESTART_DELAY_SECONDS%s, max retries %NFG_AUTO_RESTART_MAX_RETRIES%^)
echo   Electron windows: NFG Crash + App Chat only
echo   Hangman: OFF ^(NFG_START_HANGMAN=0^)
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
echo   Word Games:        %WORD_GAMES_PORT%  ^(NFG Words ??? auto-start^)
echo.
echo --- Public ^(https://y666suf.com^) ---
echo   Website / sideload:  https://y666suf.com/sideload
echo   Crash stream:        http://127.0.0.1:%PORT%/
echo.
echo --- NFG Words mobile ---
echo   Login:       POST https://y666suf.com/api/word-games/players/login
echo   Leaderboard: GET  https://y666suf.com/api/word-games/leaderboard
echo   Source repo: %USERPROFILE%\Documents\nfg-word-games
echo.
echo --- Shared APIs ---
echo   App chat:    https://y666suf.com/api/mobile/chat
echo   Presence:    https://y666suf.com/api/mobile/platform/status
echo   Crash IPA:   https://y666suf.com/download/nfg-crash.ipa
echo.
where %HANGMAN_PYTHON% >nul 2>&1
if errorlevel 1 (
  echo WARNING: Python ^(%HANGMAN_PYTHON%^) not found - Word Games may not start.
  echo   Install Python 3 or set WORD_GAMES_PYTHON=full\path\to\python.exe
  echo.
) else (
  if exist "%USERPROFILE%\Documents\nfg-word-games\server.py" (
    echo Word Games source: %USERPROFILE%\Documents\nfg-word-games
  ) else (
    echo WARNING: nfg-word-games\server.py not found in Documents - Word Games disabled.
    set "NFG_START_WORD_GAMES=0"
  )
  echo.
)
if exist "%NFG_IPA_FILE%" (
  echo Crash IPA:   %NFG_IPA_FILE%
) else (
  echo Crash IPA:   not found - run git pull for releases\ipa\NFG-Crash.ipa
)
echo.
if /I not "%NFG_BUILD_WEBSITE%"=="0" (
  if exist "%NFG_WEBSITE_FRONTEND_DIR%\package.json" (
    echo Building React website for port %PORT% ...
    pushd "%NFG_WEBSITE_FRONTEND_DIR%"
    set "REACT_APP_BACKEND_URL="
    if not exist "node_modules\@craco\craco" (
      echo Installing website deps ^(includes craco^)...
      set "NODE_ENV="
      call corepack yarn install --production=false
    )
    set "PATH=%CD%\node_modules\.bin;%PATH%"
    set "NODE_ENV="
    set "CI=true"
    call corepack yarn build
    if errorlevel 1 (
      echo.
      echo Website build failed. Public domain may show legacy site until build succeeds.
      echo.
    )
    popd
  )
)
echo Starting Electron + Node + tunnel...
echo.
call "%~dp0run-electron.bat"

endlocal
exit /b %errorlevel%
