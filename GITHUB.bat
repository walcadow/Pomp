@echo off
chcp 65001 >nul
title Pomp - GitHub
cd /d "%~dp0"

where git >nul 2>&1
if not errorlevel 1 goto git_var
if exist "C:\Program Files\Git\cmd\git.exe" set "PATH=C:\Program Files\Git\cmd;%PATH%"
where git >nul 2>&1
if errorlevel 1 goto git_yok
:git_var

if exist ".git" goto depo_var
echo [1/4] Yerel depo olusturuluyor...
git init -b main >nul
:depo_var

git config user.name >nul 2>&1
if not errorlevel 1 goto kimlik_var
echo.
echo Kayitlarda gorunecek isim ve e-posta (GitHub hesabinizdakiyle ayni olmasi iyi olur):
set /p GNAME=Adiniz: 
set /p GMAIL=E-posta: 
git config user.name "%GNAME%"
git config user.email "%GMAIL%"
:kimlik_var

echo [2/4] Dosyalar kaydediliyor...
git add -A
git commit -m "Pomp guncelleme %date% %time:~0,5%" >nul 2>&1
git log --oneline -1

git remote get-url origin >nul 2>&1
if not errorlevel 1 goto uzak_var
echo.
echo [3/4] GitHub'da olusturdugunuz deponun adresini yapistirin.
echo Ornek: https://github.com/kullaniciadi/pomp.git
set /p REPO=Adres: 
git remote add origin "%REPO%"
:uzak_var

echo.
echo [4/4] GitHub'a gonderiliyor. Tarayicida GitHub girisi acilirsa giris yapip izin verin...
git push -u origin main
if errorlevel 1 goto hata

echo.
echo ============================================================
echo  Tamam! Kodunuz GitHub'da.
echo  Bundan sonra degisiklikleri gondermek icin GITHUB.bat'i
echo  tekrar calistirmaniz yeterli.
echo ============================================================
pause
exit /b 0

:git_yok
echo HATA: Git bulunamadi. https://git-scm.com/download/win adresinden kurun.
pause
exit /b 1

:hata
echo.
echo Gonderme basarisiz oldu. Ekrandaki mesaji Claude'a yapistirin.
pause
exit /b 1
