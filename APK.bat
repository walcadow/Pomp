@echo off
chcp 65001 >nul
title Pomp - APK olustur
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
set "LOG=%~dp0apk_log.txt"
cd /d "%~dp0mobile"
echo Pomp APK kaydi > "%LOG%"

rem Bilgisayarin yerel agdaki adresini bul (Docker/WSL sanal kartlarini atla)
set "IP="
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'vEthernet|Loopback|WSL|Docker|VirtualBox|VMware' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' } | Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress"`) do set "IP=%%a"

echo.
if "%IP%"=="" goto ip_sor
echo Bilgisayarinizin yerel adresi: %IP%
echo Telefon bu adresten sunucuya baglanacak.
echo Dogruysa sadece Enter'a basin, farkli bir adres kullanmak icin yazin.
set "YENI="
set /p YENI=Adres [%IP%]: 
if not "%YENI%"=="" set "IP=%YENI%"
goto ip_tamam

:ip_sor
echo Bilgisayarin adresi bulunamadi. Asagidaki IPv4 adreslerinden Wi-Fi olanini yazin:
ipconfig | find "IPv4"
set /p IP=Adres: 

:ip_tamam
echo Sunucu adresi: http://%IP%:3000 >> "%LOG%"
echo.
echo Sunucu adresi: http://%IP%:3000
echo APK olusturuluyor, 5-10 dakika surebilir...
call flutter build apk --release --dart-define=API_URL=http://%IP%:3000 >> "%LOG%" 2>&1
if errorlevel 1 goto hata
copy /y "build\app\outputs\flutter-apk\app-release.apk" "%~dp0Pomp.apk" >nul
echo.
echo ============================================================
echo  Hazir: POMP klasorundeki Pomp.apk dosyasini telefona kurun.
echo.
echo  Telefonda once tarayicida su adresi acip deneyin:
echo     http://%IP%:3000/health
echo  {"ok":true} gorurseniz uygulama da baglanir.
echo  Telefon ve bilgisayar AYNI Wi-Fi aginda olmali.
echo ============================================================
pause
exit /b 0

:hata
echo.
echo Hata olustu. Claude'a "apk hata verdi" yazin.
pause
exit /b 1
