@echo off
chcp 65001 >nul
title Pomp - Windows'ta calistir
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
set "LOG=%~dp0windows_log.txt"
cd /d "%~dp0mobile"
echo Pomp windows kaydi > "%LOG%"

if exist "windows\runner" goto calistir
echo [1/2] Windows proje dosyalari olusturuluyor...
call flutter create --org com.walcadow --project-name pomp --platforms windows . >> "%LOG%" 2>&1
if errorlevel 1 goto hata

:calistir
echo [2/2] Uygulama derleniyor ve aciliyor. Ilk seferde birkac dakika surebilir...
echo Bu pencereyi kapatirsaniz uygulama da kapanir.
call flutter run -d windows >> "%LOG%" 2>&1
if errorlevel 1 goto hata
exit /b 0

:hata
echo.
echo Bir sorun olustu. Claude'a "windows hata verdi" yazin; windows_log.txt dosyasini okuyacak.
pause
exit /b 1
