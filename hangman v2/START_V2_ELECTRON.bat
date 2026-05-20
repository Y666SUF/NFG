@echo off
setlocal
cd /d "%~dp0"
set "ROOT=%~dp0"

echo [1/2] Starting Hangman backend (FastAPI) on :19876 ...
start "Hangman V2 Backend" cmd /k "cd /d \"%ROOT%\" && py -m uvicorn server:app --host 0.0.0.0 --port 19876"

echo [2/2] Starting Electron V2 app ...
start "Hangman V2 Electron" cmd /k "cd /d \"%ROOT%app-v2\" && npm install && npm run dev"

echo.
echo The Electron window opens automatically after Vite starts.
echo Keep both terminal windows open while playing.
endlocal
