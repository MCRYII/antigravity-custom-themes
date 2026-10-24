@echo off
chcp 65001 >nul
echo ============================================
echo   Antigravity Custom Themes - Installer
echo ============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
