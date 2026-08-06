@echo off
title Profile Migration Tool

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ProfileMigration.ps1"

pause