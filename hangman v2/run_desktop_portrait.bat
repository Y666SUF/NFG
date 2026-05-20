@echo off
setlocal
cd /d "%~dp0"

set PYTHONUNBUFFERED=1
set PYTHONDONTWRITEBYTECODE=1

REM Same port variable as run_web.bat / run_desktop.bat (default 19876 if unset).
if not defined HANGMAN_WEB_PORT set HANGMAN_WEB_PORT=19876

REM --- Post !how / !play into TikTok LIVE chat (same as run_desktop.bat) ---
REM Viewers type those IN TIKTOK LIVE CHAT. Set on this PC before starting:
REM   set WHITELIST_AUTHENTICATED_SESSION_ID_HOST=tiktok.eulerstream.com
REM   set TIKTOK_CHAT_SESSION_ID=your_browser_sessionid_cookie
REM   set TIKTOK_CHAT_TT_TARGET_IDC=your_tt-target-idc_cookie
REM Quick cookie copy (Chrome or Edge): log in at https://www.tiktok.com with a SPARE account,
REM   F12 ^> Application ^> Cookies ^> https://www.tiktok.com
REM   sessionid  ^> value = TIKTOK_CHAT_SESSION_ID
REM   tt-target-idc  ^> value = TIKTOK_CHAT_TT_TARGET_IDC
REM WHITELIST_* is fixed (Euler bridge); not a cookie — type it exactly as above.
REM Portrait window: 9:16-ish for TikTok Live Studio vertical capture (?desktop=1&portrait=1).
REM Zoom: Ctrl+Plus / Ctrl+Minus / Ctrl+0 in the Hangman window.

echo.
echo [%date% %time%] Hangman desktop PORTRAIT — directory: %cd%
echo   Native window (WebView2), vertical layout. Server: http://127.0.0.1:%HANGMAN_WEB_PORT%
echo   For landscape desktop window, use run_desktop.bat. For OBS Browser Source only, use run_web.bat.
echo.

py -3 -m pip install -r requirements.txt -q
if errorlevel 1 (
  echo pip install failed.
  exit /b 1
)

py -3 desktop_portrait.py
exit /b %errorlevel%
