@echo off
chcp 65001 >nul
title Pomp - Sunucu
set "LOG=%~dp0sunucu_log.txt"
cd /d "%~dp0"
echo Pomp sunucu kaydi > "%LOG%"

where docker >nul 2>&1
if errorlevel 1 goto docker_yok

echo [1/4] Docker Desktop'in calistigi kontrol ediliyor...
docker info >nul 2>&1
if not errorlevel 1 goto docker_hazir

echo Docker Desktop kapali gorunuyor, aciliyor...
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
echo Docker'in hazir olmasi bekleniyor, 1-2 dakika surebilir...
set /a SAYAC=0
:docker_bekle
timeout /t 3 /nobreak >nul
docker info >nul 2>&1
if not errorlevel 1 goto docker_hazir
set /a SAYAC+=1
if %SAYAC% lss 60 goto docker_bekle
echo HATA: Docker baslatilamadi. Docker Desktop'i acip "Engine running" yazisini bekleyin, sonra bu dosyayi tekrar calistirin.
echo Docker baslamadi >> "%LOG%"
pause
exit /b 1

:docker_hazir
echo [2/4] Ayar dosyasi hazirlaniyor...
if not exist ".env" copy ".env.example" ".env" >nul

echo [3/4] Sunucu ve veritabani baslatiliyor. Ilk seferde 3-5 dakika surebilir...
docker compose up -d --build >> "%LOG%" 2>&1
if errorlevel 1 goto hata

echo [4/4] Sunucunun cevap vermesi bekleniyor...
set /a SAYAC=0
:saglik_bekle
curl -s http://localhost:3000/health | find "ok" >nul
if not errorlevel 1 goto hazir
set /a SAYAC+=1
if %SAYAC% geq 40 goto hata
timeout /t 3 /nobreak >nul
goto saglik_bekle

:hazir
echo SUNUCU HAZIR >> "%LOG%"
echo.
echo ============================================================
echo  Sunucu calisiyor: http://localhost:3000/health
echo  Docker Desktop acik oldugu surece sunucu calisir.
echo  Durdurmak icin: SUNUCU_DURDUR.bat
echo ============================================================
pause
exit /b 0

:docker_yok
echo HATA: Docker bulunamadi. Docker Desktop'i kurduktan sonra bilgisayari yeniden baslatin.
echo Docker bulunamadi >> "%LOG%"
pause
exit /b 1

:hata
echo ===== API KAYITLARI ===== >> "%LOG%"
docker compose logs --tail 80 api >> "%LOG%" 2>&1
echo.
echo Bir sorun olustu. Claude'a "sunucu hata verdi" yazin; sunucu_log.txt dosyasini okuyacak.
pause
exit /b 1
