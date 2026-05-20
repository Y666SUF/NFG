@echo off
setlocal EnableExtensions
cd /d "%~dp0"

chcp 65001 >nul 2>&1

echo Build NFGCrash.exe (Node.js 18+ and npm on this PC once; exe embeds Node 18 via pkg)
echo.

set "NODE_EXE="

where node >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%I in ('where node 2^>nul') do (
    set "NODE_EXE=%%I"
    goto :have_node
  )
)

for /f "delims=" %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0find-node.ps1" 2^>nul') do set "NODE_EXE=%%I"

if defined NODE_EXE goto :have_node

echo Node.js was not found.
echo.
echo Option A - Install: https://nodejs.org/ ^(LTS, v20+^), enable "Add to PATH", sign out/in.
echo Option B - Portable: extract the Node "Windows Binary (.zip)" so you have:
echo   tools\node\node.exe   ^(same folder as this bat^)
echo.
echo Same search as run.bat ^(registry, WinGet, etc.^) is used.
echo.
pause
exit /b 1

:have_node
for %%F in ("%NODE_EXE%") do set "NODE_DIR=%%~dpF"
set "NODE_DIR=%NODE_DIR:~0,-1%"
set "PATH=%NODE_DIR%;%PATH%"

echo Using: %NODE_EXE%
for /f "delims=" %%V in ('node -p "process.version" 2^>nul') do echo Version: %%V
echo.

set "OUTEXE=NFGCrash.exe"

node -e "var m=+process.versions.node.split('.')[0]; if(m<18){console.error('Need Node.js 18+ to run npm/pkg on this machine. Got: '+process.version); process.exit(1)}"
if errorlevel 1 (
  pause
  exit /b 1
)

call npm install
if errorlevel 1 (
  echo npm install failed.
  pause
  exit /b 1
)

if not exist "dist" mkdir dist

echo.
echo Unlocking dist\NFGCrash.exe ^(close the game if it is running^)...
taskkill /F /IM NFGCrash.exe >nul 2>&1
timeout /t 2 /nobreak >nul
if exist "dist\NFGCrash.exe" (
  attrib -r "dist\NFGCrash.exe" >nul 2>&1
  del /f /q "dist\NFGCrash.exe" 2>nul
)
if exist "dist\NFGCrash.exe" (
  echo.
  echo Cannot delete dist\NFGCrash.exe — Windows still has it locked.
  echo   1. Close every NFGCrash.exe window ^(taskbar / Task Manager^)
  echo   2. Close File Explorer if the dist folder or the exe is open
  echo   3. Retry the build, or reboot if something still holds the file
  echo.
  pause
  exit /b 1
)

call npm run build:exe
if errorlevel 1 (
  echo.
  echo pkg could not overwrite dist\NFGCrash.exe — building dist\NFGCrash-new.exe instead...
  call npm run build:exe:new
  if errorlevel 1 (
    echo pkg still failed. See messages above.
    pause
    exit /b 1
  )
  echo.
  echo Built: dist\NFGCrash-new.exe
  echo Use this file, or close the old NFGCrash.exe and rename this one to NFGCrash.exe
  set "OUTEXE=NFGCrash-new.exe"
  goto :done
)

:done
echo.
echo Done. Next steps:
echo   1. Open folder: dist\
echo   2. Double-click %OUTEXE% ^(a black console window will stay open^)
echo   3. In your browser go to: http://127.0.0.1:3847/
echo      ^(Chrome may open by itself; if not, paste that link yourself^)
echo   4. Optional: copy tiktok.config.example.json next to the exe as tiktok.config.json
echo.
pause
endlocal
