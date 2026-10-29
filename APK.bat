@echo off
chcp 65001 >nul
title Pomp - APK olustur
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
set "LOG=%~dp0apk_log.txt"
cd /d "%~dp0mobile"

echo Bu APK'yi gercek bir telefona kuracaksaniz, telefonun bilgisayariniza
echo ulasabilmesi icin bilgisayarin yerel IP adresi gerekiyor.
echo Asagida "IPv4" satirlarinda yazan adres (genelde 192.168.x.x):
echo.
ipconfig | find "IPv4"
echo.
set "IP="
set /p IP=IP adresini yazip Enter'a basin (sadece emulator icin bos birakin): 

if "%IP%"=="" (
  set "DEFINE="
) else (
  set "DEFINE=--dart-define=API_URL=http://%IP%:3000"
)

echo.
echo APK olusturuluyor, 5-10 dakika surebilir...
call flutter build apk --release %DEFINE% > "%LOG%" 2>&1
if errorlevel 1 (
  echo Hata olustu. Claude'a "apk hata verdi" yazin.
  pause
  exit /b 1
)
copy /y "build\app\outputs\flutter-apk\app-release.apk" "%~dp0Pomp.apk" >nul
echo.
echo Hazir: POMP klasorundeki Pomp.apk dosyasini telefona atip kurabilirsiniz.
pause
