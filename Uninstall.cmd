@echo off
rem Uninstalls SteelSeries Capture Reaper. Double-click this file and approve the UAC prompt.
rem Works whether or not you still have the downloaded copy of CaptureReaper.ps1.
set "PS1=%~dp0CaptureReaper.ps1"
if not exist "%PS1%" set "PS1=%ProgramData%\CaptureReaper\CaptureReaper.ps1"
if not exist "%PS1%" (
    echo CaptureReaper.ps1 not found. Use the copy-paste uninstall in the README instead.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Uninstall
timeout /t 5 >nul
