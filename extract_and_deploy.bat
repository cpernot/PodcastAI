@echo off
setlocal
echo ========================================
echo     PodcastAI: Unit Extract ^& Deploy
echo ========================================
echo.
echo IMPORTANT: Make sure the audio has finished 
echo playing/generating in NotebookLM first.
echo.

:: Ask for the Unit Number
set /p UNIT_NUM="Enter Unit Number (e.g. 038): "

echo.
echo [1/2] Switching to project directory...
cd /d "c:\Users\owner\Documents\PodcastAI"

echo [2/2] Running extraction and deployment for Unit %UNIT_NUM%...
powershell -ExecutionPolicy Bypass -File ".\extract_from_cache.ps1" -unitNum "%UNIT_NUM%"

echo.
echo ========================================
echo              PROCESS COMPLETE
echo ========================================
echo.
pause
