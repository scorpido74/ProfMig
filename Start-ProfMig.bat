@echo off
title Profile Migration Tool

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\ProfMig.ps1"

pause