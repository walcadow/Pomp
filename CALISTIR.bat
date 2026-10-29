@echo off
chcp 65001 >nul
title Pomp - Uygulamayi calistir
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%LOCALAPPDATA%\Android\sdk\platform-tools;%PATH%"
set "LOG=%~dp0calistir_log.txt"
cd /d "%~dp0mobile"
echo CALISIYOR > "%LOG%"

echo [1/3] Sanal telefon aciliyor...
call flutter emulators --launch Medium_Phone_API_37.0 >> "%LOG%" 2>&1

echo [2/3] Sanal telefonun acilmasi bekleniyor...
adb wait-for-device
:bekle
for /f "delims=" %%i in ('adb shell getprop sys.boot_completed 2^>nul') do set BOOT=%%i
if not "%BOOT%"=="1" (
  timeout /t 3 /nobreak >nul
  goto bekle
)
echo Sanal telefon hazir. >> "%LOG%"

echo [3/3] Uygulama derleniyor ve aciliyor. Ilk seferde 5-10 dakika surebilir...
echo Bu pencereyi kapatirsaniz uygulama da durur.
call flutter run -d emulator >> "%LOG%" 2>&1
echo ===== BITTI ===== >> "%LOG%"
