@echo off
chcp 65001 >nul
title Pomp - Internet tuneli
cd /d "%~dp0"
set "LOG=%~dp0tunel_log.txt"
echo Pomp tunel kaydi > "%LOG%"

docker info >nul 2>&1
if errorlevel 1 goto docker_kapali

echo [1/3] Sunucu kontrol ediliyor...
docker compose up -d >> "%LOG%" 2>&1

echo [2/3] Tunel aciliyor...
docker compose --profile tunnel up -d --force-recreate tunnel >> "%LOG%" 2>&1
if errorlevel 1 goto hata

echo [3/3] Internet adresi bekleniyor...
set "ADRES="
set /a SAYAC=0
:bekle
timeout /t 3 /nobreak >nul
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$m = (docker compose logs tunnel 2>$null | Select-String -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Last 1); if ($m) { $m }"`) do set "ADRES=%%a"
if not "%ADRES%"=="" goto hazir
set /a SAYAC+=1
if %SAYAC% lss 30 goto bekle
goto hata

:hazir
echo %ADRES%> "%~dp0tunel_adres.txt"
echo Tunel adresi: %ADRES% >> "%LOG%"
echo.
echo ============================================================
echo  Sunucunuz internette:
echo.
echo     %ADRES%
echo.
echo  Telefonda Pomp uygulamasini acin, giris ekraninin altindaki
echo  "Sunucu ayari"na dokunup bu adresi yazin ve Kaydet deyin.
echo  (Adres POMP klasorundeki tunel_adres.txt dosyasina da yazildi.)
echo.
echo  Tunel, Docker acik oldugu surece calisir. Docker yeniden
echo  baslarsa ADRES DEGISIR: bu dosyayi tekrar calistirin.
echo  Kapatmak icin: TUNEL_KAPAT.bat
echo ============================================================
pause
exit /b 0

:docker_kapali
echo Docker Desktop kapali. Once Docker Desktop'i acin ya da SUNUCU.bat'i calistirin.
pause
exit /b 1

:hata
echo ===== TUNEL KAYITLARI ===== >> "%LOG%"
docker compose logs --tail 40 tunnel >> "%LOG%" 2>&1
echo.
echo Tunel acilamadi. Claude'a "tunel hata verdi" yazin.
pause
exit /b 1
