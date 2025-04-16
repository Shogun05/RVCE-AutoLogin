@echo off
REM Bypass execution policy and run setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

REM Uncomment the following line if you want to run login.ps1 after setup.ps1
REM powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0login.ps1"

REM Start executing setup.ps1 in a new PowerShell window
@REM start powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"