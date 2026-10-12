@echo off
rem Installs SteelSeries Capture Reaper. Double-click this file and approve the UAC prompt.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CaptureReaper.ps1" -Install
timeout /t 5 >nul
