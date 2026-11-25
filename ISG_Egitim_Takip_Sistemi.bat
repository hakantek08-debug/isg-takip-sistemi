@echo off
chcp 65001 >nul
title ISG Egitim Takip ve Bildirim Sistemi

echo ============================================================
echo   OSMANGAZI BELEDIYESI PERSONEL A.S.
echo   ISG Egitim Takip ve Bildirim Sistemi Baslatiliyor...
echo ============================================================
echo.

cd /d "%~dp0"

echo [1/2] Bildirim ve gecerlilik kontrolu yapiliyor...
powershell -ExecutionPolicy Bypass -File "bildirim_kontrol.ps1"

echo.
echo [2/2] Web sunucusu calistiriliyor ve tarayici aciliyor...
echo Sistem Adresi: http://localhost:5050
echo.
echo Bu pencereyi kapatirsaniz sunucu durur. Simge durumuna kucultebilirsiniz.
echo.

powershell -ExecutionPolicy Bypass -File "server.ps1" -Port 5050

pause
