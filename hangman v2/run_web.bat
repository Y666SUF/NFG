@echo off
setlocal
REM Always run from this repo so static/ and server.py match your latest files.
cd /d "%~dp0"

set PYTHONUNBUFFERED=1
set PYTHONDONTWRITEBYTECODE=1

REM Optional: set TIKTOK_LIVE_USERNAME / TIKTOK_HOST_USERNAME before running, or edit defaults in server.py
REM
REM --- Post !how / !play into TikTok LIVE chat (same machine as this server) ---
REM Type those commands IN TIKTOK LIVE CHAT (not in the browser overlay). You need a LIVE stream and:
REM   set WHITELIST_AUTHENTICATED_SESSION_ID_HOST=tiktok.eulerstream.com
REM   set TIKTOK_CHAT_SESSION_ID=your_browser_sessionid_cookie
REM   set TIKTOK_CHAT_TT_TARGET_IDC=your_tt-target-idc_cookie   (from tiktok.com in DevTools ^> Application ^> Cookies)
REM Get cookies from a spare TikTok account (Chrome: F12 ^> Application ^> Cookies ^> https://www.tiktok.com).
REM Restart this window after setting. Console will print [Guide] lines when someone uses !how.
REM Default port 19876 = new browser "origin" so caches from 127.0.0.1:8765 do not apply. Override: set HANGMAN_WEB_PORT=8765
if not defined HANGMAN_WEB_PORT set HANGMAN_WEB_PORT=19876
echo.
echo [%date% %time%] Hangman web — directory: %cd%
echo   Open http://127.0.0.1:%HANGMAN_WEB_PORT%  (close any OLD console running uvicorn first, or the port stays busy^)
echo   If the overlay still looks old, OBS may still point at another URL — update Browser Source to this URL.
echo   TikTok LIVE must be active for chat, or set TIKTOK_LIVE_USERNAME=your_handle
echo   --reload restarts the app when you save .py files; refresh the browser after HTML/JS/CSS changes.
echo.

py -3 -m pip install -r requirements.txt -q
if errorlevel 1 (
  echo pip install failed.
  exit /b 1
)

REM HANGMAN_WEB_RELOAD=0 disables auto-reload (single process). Default: reload on Python changes.
if "%HANGMAN_WEB_RELOAD%"=="0" (
  py -3 -m uvicorn server:app --host 0.0.0.0 --port %HANGMAN_WEB_PORT%
) else (
  py -3 -m uvicorn server:app --host 0.0.0.0 --port %HANGMAN_WEB_PORT% --reload --reload-dir .
)
