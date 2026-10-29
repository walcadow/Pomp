@echo off
chcp 65001 >nul
title Pomp - APK olustur
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
set "LOG=%~dp0apk_log.txt"
cd /d "%~dp0mobile"
echo Pomp APK kaydi > "%LOG%"

echo Uygulama mobile\lib\config.dart icindeki sunucu adresine baglanacak.
echo APK olusturuluyor, 5-10 dakika surebilir...
call flutter build apk --release >> "%LOG%" 2>&1
if errorlevel 1 goto hata
copy /y "build\app\outputs\flutter-apk\app-release.apk" "%~dp0Pomp.apk" >nul
echo.
echo ============================================================
echo  Hazir: POMP klasorundeki Pomp.apk dosyasini telefona kurun.
echo ============================================================
pause
exit /b 0

:hata
echo.
echo Hata olustu. Claude'a "apk hata verdi" yazin.
pause
exit /b 1
