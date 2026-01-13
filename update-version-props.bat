@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0update-version-props.ps1" %*
echo Press Enter key to continue...
set /p dummyVar=""