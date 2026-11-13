@echo off
setlocal
for /f "tokens=2 delims=:" %%a in ('chcp') do set "OLD_CP=%%a"
if defined OLD_CP set "OLD_CP=%OLD_CP: =%"
chcp 65001 >nul
echo ============================================
echo   Antigravity Custom Themes - Uninstaller
echo ============================================
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
set "EXIT_CODE=%ERRORLEVEL%"
echo.
pause
if defined OLD_CP chcp %OLD_CP% >nul 2>&1
exit /b %EXIT_CODE%
