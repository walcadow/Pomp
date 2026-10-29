@echo off
chcp 65001 >nul
title Pomp - Windows surumu olustur
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
set "LOG=%~dp0exe_log.txt"
cd /d "%~dp0mobile"
echo Pomp exe kaydi > "%LOG%"

if exist "windows\runner" goto derle
call flutter create --org com.walcadow --project-name pomp --platforms windows . >> "%LOG%" 2>&1
if errorlevel 1 goto hata

:derle
echo Windows surumu olusturuluyor, birkac dakika surebilir...
call flutter build windows --release >> "%LOG%" 2>&1
if errorlevel 1 goto hata
if exist "%~dp0Pomp_Windows" rmdir /s /q "%~dp0Pomp_Windows"
xcopy /e /i /q "build\windows\x64\runner\Release" "%~dp0Pomp_Windows" >nul
echo.
echo Hazir: POMP\Pomp_Windows klasorundeki pomp.exe ile uygulamayi acabilirsiniz.
echo Baska bir bilgisayara verirken klasorun TAMAMINI kopyalayin.
pause
exit /b 0

:hata
echo.
echo Bir sorun olustu. Claude'a "exe hata verdi" yazin; exe_log.txt dosyasini okuyacak.
pause
exit /b 1
