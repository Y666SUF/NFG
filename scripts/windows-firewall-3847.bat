@echo off
setlocal

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo This script must run as Administrator.
  echo Right-click this file and choose "Run as administrator".
  pause
  exit /b 1
)

echo Adding inbound firewall rules for NFG Crash on TCP 3847...

netsh advfirewall firewall add rule name="NFG Crash TCP 3847 (Private)" dir=in action=allow protocol=TCP localport=3847 profile=private
netsh advfirewall firewall add rule name="NFG Crash TCP 3847 (Public)" dir=in action=allow protocol=TCP localport=3847 profile=public

echo Done.
echo You can verify with:
echo   netsh advfirewall firewall show rule name^="NFG Crash TCP 3847 (Private)"
echo   netsh advfirewall firewall show rule name^="NFG Crash TCP 3847 (Public)"
pause
