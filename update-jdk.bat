@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0update-jdk.ps1" %*
