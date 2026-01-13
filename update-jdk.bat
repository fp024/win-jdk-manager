@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0update-jdk.ps1" %*
echo Press Enter key to continue...
set /p dummyVar=""
