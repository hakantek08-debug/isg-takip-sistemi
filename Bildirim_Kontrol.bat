@echo off
chcp 65001 >nul
title ISG Egitim Yaklasanlar Bildirim Kontrolu

cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "bildirim_kontrol.ps1" -ShowDialog

pause
