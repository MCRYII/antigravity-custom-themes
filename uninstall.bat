@echo off
chcp 65001 >nul
echo ============================================
echo   Antigravity Custom Themes - Uninstaller
echo ============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
echo.
pause
