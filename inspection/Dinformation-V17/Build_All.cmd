@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
chcp 65001 >nul
color 0B
set "ROOT=%~dp0"
if not exist "%ROOT%log" mkdir "%ROOT%log"
if not exist "%ROOT%Data" mkdir "%ROOT%Data"
set "LOG=%ROOT%log\Build_All.log"
set "STATUS=%ROOT%Data\BUILD-STATUS.txt"
set "FAILED_STEP="
set "RC=0"
set "S1=NOT RUN"
set "S2=NOT RUN"
set "S3=NOT RUN"
set "S4=NOT RUN"
>"%LOG%" echo ============================================================
>>"%LOG%" echo Dinformation V17 - BUILD ALL
>>"%LOG%" echo Started: %DATE% %TIME%
>>"%LOG%" echo Final runtime: Dprogram\DinformationC22.dll / DinformationC25.dll / DinformationG18.dll / DinformationG27.dll
>>"%LOG%" echo ============================================================
echo Dinformation V17 - BUILD ALL
echo Build order:
echo   1. Dinformation AutoCAD 2022 V17
echo   2. Dinformation AutoCAD 2025 V17
echo   3. Dinformation GstarCAD 2018 V17
echo   4. Dinformation GstarCAD 2027 V17
echo   5. Assemble shared Dprogram folder
call :RunStep "1/5 Dinformation AutoCAD 2022 V17" "%ROOT%Dinformation-AutoCAD2022-V17\Build_Release.cmd" S1
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto :FAIL
call :RunStep "2/5 Dinformation AutoCAD 2025 V17" "%ROOT%Dinformation-AutoCAD2025-V17\Build_Release.cmd" S2
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto :FAIL
call :RunStep "3/5 Dinformation GstarCAD 2018 V17" "%ROOT%Dinformation-GstarCAD2018-V17\Build_Release.cmd" S3
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto :FAIL
call :RunStep "4/5 Dinformation GstarCAD 2027 V17" "%ROOT%Dinformation-GstarCAD2027-V17\Build_Release.cmd" S4
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto :FAIL
set "FAILED_STEP=5/5 Assemble shared Dprogram"
echo [%FAILED_STEP%]
>>"%LOG%" echo.
>>"%LOG%" echo ------------------------------------------------------------
>>"%LOG%" echo [%FAILED_STEP%]
>>"%LOG%" echo ------------------------------------------------------------
call :AssembleDprogram
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto :FAIL
echo [%FAILED_STEP%] PASS
>>"%LOG%" echo [%FAILED_STEP%] PASS
call :WriteStatus PASS
color 0A
>>"%LOG%" echo BUILD ALL PASS
>>"%LOG%" echo Finished: %DATE% %TIME%
echo.
echo ============================================================
echo [BUILD PASS] Dinformation V17 - ALL TARGETS
echo Runtime: %ROOT%Dprogram
echo Load only the matching DLL for the active CAD host.
echo Log: %LOG%
echo ============================================================
echo Nhấn phím bất kỳ để thoát...
pause >nul
exit /b 0

:FAIL
color 0C
if "%RC%"=="0" set "RC=1"
call :WriteStatus FAIL
>>"%LOG%" echo BUILD ALL FAILED - Step: %FAILED_STEP% - Error: %RC%
>>"%LOG%" echo Finished: %DATE% %TIME%
echo.
echo ============================================================
echo [BUILD FAILED] Dinformation V17
echo Step: %FAILED_STEP%
echo Error code: %RC%
echo Log: %LOG%
echo ============================================================
echo Nhấn phím bất kỳ để thoát...
pause >nul
exit /b %RC%

:RunStep
set "FAILED_STEP=%~1"
set "STEP_CMD=%~2"
set "OUTVAR=%~3"
set "STEP_OUT=%TEMP%\Dinformation_BuildStep_%RANDOM%_%RANDOM%.log"
>>"%LOG%" echo.
>>"%LOG%" echo ------------------------------------------------------------
>>"%LOG%" echo [%FAILED_STEP%]
>>"%LOG%" echo ------------------------------------------------------------
echo [%FAILED_STEP%]
if not exist "%STEP_CMD%" (echo ERROR: Build step script missing: %STEP_CMD%& set "%OUTVAR%=FAIL-MISSING-CMD"& set "RC=90"& exit /b 90)
call "%STEP_CMD%" /nopause > "%STEP_OUT%" 2>&1
set "RC=%ERRORLEVEL%"
cd /d "%ROOT%"
if exist "%STEP_OUT%" (type "%STEP_OUT%"& type "%STEP_OUT%">>"%LOG%"& del /q "%STEP_OUT%" >nul 2>nul)
if not "%RC%"=="0" (set "%OUTVAR%=FAIL-%RC%"& exit /b %RC%)
set "%OUTVAR%=PASS"
echo [%FAILED_STEP%] PASS
>>"%LOG%" echo [%FAILED_STEP%] PASS
exit /b 0

:AssembleDprogram
set "DST=%ROOT%Dprogram"
if not exist "%ROOT%Dinformation-AutoCAD2022-V17\bin\DinformationC22.dll" (echo ERROR: DinformationC22.dll missing.& exit /b 2)
if not exist "%ROOT%Dinformation-AutoCAD2025-V17\bin\DinformationC25.dll" (echo ERROR: DinformationC25.dll missing.& exit /b 3)
if not exist "%ROOT%Dinformation-GstarCAD2018-V17\bin\DinformationG18.dll" (echo ERROR: DinformationG18.dll missing.& exit /b 4)
if not exist "%ROOT%Dinformation-GstarCAD2027-V17\bin\DinformationG27.dll" (echo ERROR: DinformationG27.dll missing.& exit /b 5)
if exist "%DST%" rmdir /s /q "%DST%"
mkdir "%DST%" >nul 2>nul
copy /Y "%ROOT%Dinformation-AutoCAD2022-V17\bin\DinformationC22.dll" "%DST%\DinformationC22.dll" >nul || exit /b 6
copy /Y "%ROOT%Dinformation-AutoCAD2025-V17\bin\DinformationC25.dll" "%DST%\DinformationC25.dll" >nul || exit /b 7
copy /Y "%ROOT%Dinformation-GstarCAD2018-V17\bin\DinformationG18.dll" "%DST%\DinformationG18.dll" >nul || exit /b 8
copy /Y "%ROOT%Dinformation-GstarCAD2027-V17\bin\DinformationG27.dll" "%DST%\DinformationG27.dll" >nul || exit /b 9
>"%DST%\README.txt" echo Dinformation V17 shared multi-host runtime.
>>"%DST%\README.txt" echo Load only the matching DLL for the active CAD host:
>>"%DST%\README.txt" echo   AutoCAD 2022  = DinformationC22.dll
>>"%DST%\README.txt" echo   AutoCAD 2025  = DinformationC25.dll
>>"%DST%\README.txt" echo   GstarCAD 2018 = DinformationG18.dll
>>"%DST%\README.txt" echo   GstarCAD 2027 = DinformationG27.dll
>>"%DST%\README.txt" echo Command: DINFORMATION
>>"%DST%\README.txt" echo Reference SDK DLLs are build-only and are NOT copied to Dprogram.
echo SHARED DPROGRAM PASS: %DST%
exit /b 0

:WriteStatus
>"%STATUS%" echo Dinformation-V17 BUILD STATUS
>>"%STATUS%" echo Result        : %~1
>>"%STATUS%" echo AutoCAD 2022  : !S1!
>>"%STATUS%" echo AutoCAD 2025  : !S2!
>>"%STATUS%" echo GstarCAD 2018 : !S3!
>>"%STATUS%" echo GstarCAD 2027 : !S4!
>>"%STATUS%" echo NETLOAD       : NOT VERIFIED
>>"%STATUS%" echo Updated       : %DATE% %TIME%
exit /b 0
