@echo off
chcp 65001 >nul
title Pomp - Adim 2
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
set "LOG=%~dp0adim2_log.txt"
cd /d "%~dp0mobile"
echo Pomp adim 2 kaydi > "%LOG%"

echo.
echo [1/3] Yazilan kod kontrol ediliyor (flutter analyze)...
echo ===== ANALYZE ===== >> "%LOG%"
call flutter analyze >> "%LOG%" 2>&1

echo [2/3] Sanal telefonlar listeleniyor...
echo ===== EMULATORS ===== >> "%LOG%"
call flutter emulators >> "%LOG%" 2>&1

echo.
echo [3/3] Android lisanslari
echo ------------------------------------------------------------
echo  Simdi Android lisans metinleri gosterilecek.
echo  Her soruda klavyeden  y  yazip Enter'a basin.
echo ------------------------------------------------------------
pause
call flutter doctor --android-licenses

echo ===== DOCTOR ===== >> "%LOG%"
call flutter doctor >> "%LOG%" 2>&1

echo.
echo Bitti. Claude'a "adim 2 bitti" yazin.
pause
