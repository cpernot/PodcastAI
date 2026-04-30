@echo off
echo ========================================
echo   PodcastAI Automation Chrome Launcher
echo ========================================
echo.
echo [1/2] Closing any existing Chrome instances...
taskkill /F /IM chrome.exe /T >nul 2>&1

echo [2/2] Starting Chrome on Port 9222...
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --remote-debugging-port=9222 --user-data-dir="C:\automation_chrome" --disable-blink-features=AutomationControlled

echo.
echo SUCCESS: Chrome is now ready for automation.
echo Link: https://notebooklm.google.com/
echo.
pause
