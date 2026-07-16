@echo off
echo ============================================
echo  BTC ANALYZER v3 - Launcher
echo ============================================
echo.
echo [1] Run once
echo [2] Run with auto-refresh (every 15 min)
echo [3] Exit
echo.
set /p choice="Select mode (1-3): "

if "%choice%"=="1" goto run_once
if "%choice%"=="2" goto run_auto
if "%choice%"=="3" goto exit

echo Invalid choice!
pause
exit /b

:run_once
python btc_analyzer_v3.py
pause
exit /b

:run_auto
echo.
echo Starting auto-refresh mode...
echo Press Ctrl+C to stop
echo.
python -c "import btc_analyzer_v3; btc_analyzer_v3.CONFIG['auto_refresh']=True; btc_analyzer_v3.main()"
pause
exit /b

:exit
exit /b
