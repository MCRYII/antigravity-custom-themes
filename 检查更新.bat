@echo off
chcp 65001 >nul
echo ============================================
echo   Antigravity Custom Themes - 检查更新
echo ============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -CheckUpdate
echo.
pause
