@echo off
title Profile Migration Tool

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\ProfMig.ps1" %*
set "PROFMIG_EXITCODE=%ERRORLEVEL%"

if "%~1"=="" pause

exit /b %PROFMIG_EXITCODE%