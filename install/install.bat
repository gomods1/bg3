@echo off
rem BG3 Access installer: runs install.ps1 and waits for a key so the result can be read.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
pause
