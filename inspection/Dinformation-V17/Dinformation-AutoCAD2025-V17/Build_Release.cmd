@echo off
setlocal EnableExtensions
cd /d "%~dp0"
chcp 65001 >nul
if not exist "log" mkdir "log"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Buildtime\Build_Release.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (color 0A& echo [Dinformation AutoCAD 2025 V17] BUILD PASS. DLL: %~dp0bin\DinformationC25.dll) else (color 0C& echo [Dinformation AutoCAD 2025 V17] BUILD FAIL. See log\Build-V17.log)
if /I not "%~1"=="/nopause" (echo.& echo Nhấn phím bất kỳ để thoát...& pause >nul)
exit /b %RC%
