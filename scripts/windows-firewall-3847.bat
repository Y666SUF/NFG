@echo off
REM Run as Administrator on your Windows game PC (right-click -> Run as administrator)
echo Adding inbound firewall rule for NFG Crash port 3847...
netsh advfirewall firewall delete rule name="NFG Crash 3847" >nul 2>&1
netsh advfirewall firewall add rule name="NFG Crash 3847" dir=in action=allow protocol=TCP localport=3847
if %ERRORLEVEL% EQU 0 (
  echo OK - port 3847 is allowed. Start the game with npm start, then test from iPhone.
) else (
  echo Failed. Right-click this file and choose "Run as administrator".
)
pause
