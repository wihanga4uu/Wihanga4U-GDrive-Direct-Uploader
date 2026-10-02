@echo off
setlocal
cd /d "%~dp0"
title Wihanga4U GDrive Direct Uploader
echo.
echo ============================================
echo       Developed by Wihanga4U
echo       github.com/wihanga4uu
echo       Wihanga4U GDrive Direct Uploader
echo ============================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GDriveUploader.ps1"
set "EC=%ERRORLEVEL%"
echo.
if not "%EC%"=="0" (
  echo The program ended with error code %EC%.
)
echo Press any key to close...
pause >nul
exit /b %EC%
