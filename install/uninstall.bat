@echo off
rem BG3 Access uninstaller: runs uninstall.ps1 and waits for a key so the result can be read.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
pause
