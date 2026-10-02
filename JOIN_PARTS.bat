@echo off
setlocal
cd /d "%~dp0"
title Join Downloaded Parts
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0JoinParts.ps1"
set "EC=%ERRORLEVEL%"
echo.
echo Press any key to close...
pause >nul
exit /b %EC%
