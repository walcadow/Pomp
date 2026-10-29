@echo off
chcp 65001 >nul
title Pomp - Kod kontrolu
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
set "LOG=%~dp0kontrol_log.txt"
cd /d "%~dp0mobile"
echo CALISIYOR > "%LOG%"
echo Kod kontrol ediliyor, pencere is bitince kendiliginden kapanacak...
echo ===== ANALYZE ===== >> "%LOG%"
call flutter analyze >> "%LOG%" 2>&1
echo ===== EMULATORS ===== >> "%LOG%"
call flutter emulators >> "%LOG%" 2>&1
echo ===== DOCTOR ===== >> "%LOG%"
call flutter doctor >> "%LOG%" 2>&1
echo ===== BITTI ===== >> "%LOG%"
