@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0update-version-props.ps1" %*
