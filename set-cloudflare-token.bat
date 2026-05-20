@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title NFG Crash - Save Cloudflare Tunnel Token

set "NFG_CF_TOKEN_FILE=%USERPROFILE%\.nfg-crash-cloudflare-token.cmd"

echo Enter your Cloudflare Tunnel token for NFG Crash.
echo It will be saved to:
echo   %NFG_CF_TOKEN_FILE%
echo.
set /p CF_TOKEN=Tunnel token: 

if "%CF_TOKEN%"=="" (
  echo.
  echo No token entered. Nothing was changed.
  echo.
  pause
  exit /b 1
)

if /I "%CF_TOKEN:~0,4%"=="set " (
  echo.
  echo Invalid input: paste only the token value, not a command.
  echo Example command to fetch token:
  echo   cloudflared tunnel token "NFG Crash"
  echo.
  pause
  exit /b 1
)

if not "%CF_TOKEN%"=="%CF_TOKEN: =%" (
  echo.
  echo Invalid input: tunnel token should not contain spaces.
  echo Paste only the long token text after --token.
  echo.
  pause
  exit /b 1
)

if "%CF_TOKEN:~60,1%"=="" (
  echo.
  echo Input looks too short to be a Cloudflare tunnel token.
  echo You may have pasted a tunnel ID instead of a token.
  echo.
  pause
  exit /b 1
)

> "%NFG_CF_TOKEN_FILE%" echo @echo off
>> "%NFG_CF_TOKEN_FILE%" echo set "NFG_CF_TUNNEL_TOKEN=%CF_TOKEN%"

echo.
echo Saved. Future runs of run-electron-cloudflare.bat will auto-load this token.
echo.
echo Launching now...
echo.
call "%~dp0run-electron-cloudflare.bat"

endlocal
exit /b %errorlevel%
