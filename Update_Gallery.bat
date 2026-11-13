@echo off
chcp 65001 >nul
title Pawansut Seva Sansthan - Gallery Update
echo ========================================================
echo   Updating Gallery Photos...
echo ========================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_gallery.ps1"
echo.
echo Press any key to close this window...
pause >nul
