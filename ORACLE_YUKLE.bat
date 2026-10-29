@echo off
chcp 65001 >nul
title Pomp - Oracle sunucusunu kur / guncelle
rem Pomp sunucusunu Oracle Cloud'a kurar veya gunceller (Windows 10/11).
rem Mac'teki ORACLE_YUKLE.command ile ayni isi yapar.
setlocal EnableDelayedExpansion
cd /d "%~dp0"
set "INFO=%~dp0sunucu_bilgileri.txt"
set "KEY=%USERPROFILE%\.ssh\pomp_oracle.key"
set "LOG=%~dp0oracle_log.txt"

echo === Pomp -^> Oracle Cloud ===
where ssh >nul 2>&1 || (set "MSG=Windows OpenSSH istemcisi bulunamadi. Ayarlar - Sistem - Isteye bagli ozellikler bolumunden 'OpenSSH Istemcisi'ni ekleyin." & goto hata)
where tar >nul 2>&1 || (set "MSG=tar komutu bulunamadi (Windows 10 1803 veya daha yenisi gerekir)." & goto hata)

rem 1) SSH anahtari: ilk seferde Indirilenler'deki Oracle anahtarini al
if not exist "%KEY%" (
  set "SRC="
  for /f "delims=" %%f in ('dir /b /o:-d "%USERPROFILE%\Downloads\ssh-key-*.key" 2^>nul') do if not defined SRC set "SRC=%USERPROFILE%\Downloads\%%f"
  if not defined SRC (set "MSG=Indirilenler klasorunde Oracle'in SSH anahtari (ssh-key-....key) bulunamadi. Anahtari sifre yoneticinizden Indirilenler'e kaydedin." & goto hata)
  if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
  copy /y "!SRC!" "%KEY%" >nul
  echo SSH anahtari alindi: !SRC!
)
rem Windows OpenSSH, anahtar dosyasini yalnizca sahibinin okuyabilmesini ister
icacls "%KEY%" /inheritance:r /grant:r "%USERNAME%:R" >nul

rem 2) Sunucu IP adresi (bir kez sorulur, sonra hatirlanir)
set "IP="
if exist "%INFO%" for /f "tokens=1,* delims==" %%a in ('findstr /b "IP=" "%INFO%"') do set "IP=%%b"
if not defined IP set /p IP=Oracle sunucusunun Public IP adresi (ornek 129.159.10.228): 
if not defined IP (set "MSG=IP adresi girilmedi." & goto hata)
set "IP=%IP: =%"

echo ^>^> Sunucuya baglaniliyor (%IP%)...
set "OPTS=-i "%KEY%" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15"
set "SSHUSER="
for %%u in (opc ubuntu) do if not defined SSHUSER (
  ssh %OPTS% -o BatchMode=yes %%u@%IP% "true" >nul 2>&1 && set "SSHUSER=%%u"
)
if not defined SSHUSER (set "MSG=Sunucuya baglanilamadi (opc ve ubuntu denendi). IP adresini ve SSH anahtarini kontrol edin." & goto hata)
echo Baglandi (kullanici: %SSHUSER%)

echo ^>^> Dosyalar gonderiliyor...
tar -czf - --exclude=node_modules --exclude=.env docker-compose.yml deploy server | ssh %OPTS% %SSHUSER%@%IP% "mkdir -p ~/pomp && tar xzf - -C ~/pomp 2>/dev/null; sed -i 's/\r$//' ~/pomp/deploy/*.sh ~/pomp/deploy/Caddyfile"
if errorlevel 1 (set "MSG=Dosyalar gonderilemedi." & goto hata)

echo ^>^> Sunucu kuruluyor/guncelleniyor (ilk kurulum 5-10 dk, guncelleme 1-3 dk surer)...
powershell -NoProfile -Command "$o = ssh -i '%KEY%' -o StrictHostKeyChecking=accept-new %SSHUSER%@%IP% 'bash ~/pomp/deploy/sunucu_kur.sh %IP%' 2>&1 | ForEach-Object { $l = $_.ToString(); Write-Host $l; $l }; $o | Set-Content -Encoding ASCII '%LOG%'"

set "URL="
set "ADMIN="
for /f "tokens=2" %%a in ('findstr /b "TAMAM " "%LOG%"') do set "URL=%%a"
for /f "tokens=1,* delims==" %%a in ('findstr /b "ADMIN_PASSWORD=" "%LOG%"') do set "ADMIN=%%b"
if not defined URL (set "MSG=Kurulum tamamlanamadi (yukaridaki kayitlara bakin)." & goto hata)

rem 3) Bilgileri kaydet ve uygulamadaki sunucu adresini guncelle
(
  echo IP=%IP%
  echo ADRES=%URL%
  echo YONETICI_PANELI=%URL%/admin
  echo YONETICI_SIFRESI=%ADMIN%
  echo SSH=ssh -i %%USERPROFILE%%\.ssh\pomp_oracle.key %SSHUSER%@%IP%
) > "%INFO%"
powershell -NoProfile -Command "$p='mobile\lib\config.dart'; $t=[IO.File]::ReadAllText($p); $t=$t -replace 'static const String sunucuAdresi = ''[^'']*'';', 'static const String sunucuAdresi = ''%URL%'';'; [IO.File]::WriteAllText($p, $t)"
del "%LOG%" >nul 2>&1

echo.
echo ============================================================
echo  Sunucu hazir:      %URL%
echo  Yonetici paneli:   %URL%/admin
echo  Yonetici sifresi:  %ADMIN%
echo  (Bu bilgiler Pomp klasorunde sunucu_bilgileri.txt dosyasinda.)
echo.
echo  Uygulama bu adrese baglanacak sekilde ayarlandi.
echo  Uygulamayi APK.bat ile yeniden derleyebilirsiniz.
echo ============================================================
pause
exit /b 0

:hata
echo.
echo HATA: %MSG%
echo Bu pencerenin ekran goruntusunu Claude'a gonderin.
pause
exit /b 1
