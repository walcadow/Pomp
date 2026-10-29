@echo off
chcp 65001 >nul
title Pomp - GitHub
cd /d "%~dp0"
set "PATH=C:\Program Files\Git\cmd;C:\Program Files\GitHub CLI;%LOCALAPPDATA%\Microsoft\WinGet\Links;%PATH%"

where git >nul 2>&1
if errorlevel 1 goto git_yok

rem ---------- 1) GitHub CLI ----------
where gh >nul 2>&1
if not errorlevel 1 goto gh_var
echo [1/5] GitHub CLI kuruluyor. Lisans sorulursa  Y  yazip Enter'a basin...
winget install --id GitHub.cli -e --source winget
where gh >nul 2>&1
if errorlevel 1 goto gh_yok
:gh_var

rem ---------- 2) Giris ----------
gh auth status >nul 2>&1
if not errorlevel 1 goto giris_var
echo.
echo [2/5] GitHub girisi
echo ------------------------------------------------------------
echo  Birazdan ekranda 8 haneli bir kod cikacak ve tarayici acilacak.
echo  Sorulursa Enter'a basin, tarayicida kodu yapistirip
echo  "Authorize" deyin. Sonra bu pencereye geri donun.
echo ------------------------------------------------------------
gh auth login --hostname github.com --git-protocol https --web
if errorlevel 1 goto hata
:giris_var
gh auth setup-git >nul 2>&1

rem ---------- 3) Yerel depo ----------
if exist ".git" goto depo_var
echo [3/5] Yerel depo olusturuluyor...
git init -b main >nul
:depo_var

git config user.name >nul 2>&1
if not errorlevel 1 goto kimlik_var
for /f "delims=" %%a in ('gh api user --jq .login') do set "GHLOGIN=%%a"
for /f "delims=" %%a in ('gh api user --jq .id') do set "GHID=%%a"
git config user.name "%GHLOGIN%"
git config user.email "%GHID%+%GHLOGIN%@users.noreply.github.com"
:kimlik_var

echo [4/5] Dosyalar kaydediliyor...
git add -A
git commit -m "Pomp guncelleme %date% %time:~0,5%" >nul 2>&1
git log --oneline -1

rem ---------- 5) GitHub'a gonder ----------
git remote get-url origin >nul 2>&1
if not errorlevel 1 goto gonder
echo [5/5] GitHub'da gizli "pomp" deposu olusturuluyor ve gonderiliyor...
gh repo create pomp --private --source . --remote origin --push
if errorlevel 1 goto hata
goto bitti

:gonder
echo [5/5] Degisiklikler GitHub'a gonderiliyor...
git push -u origin main
if errorlevel 1 goto hata

:bitti
echo.
echo ============================================================
echo  Tamam! Kodunuz GitHub'da (gizli depo):
gh repo view --json url --jq .url
echo  Sonraki degisiklikler icin GITHUB.bat'i tekrar calistirin.
echo ============================================================
pause
exit /b 0

:git_yok
echo HATA: Git bulunamadi.
pause
exit /b 1

:gh_yok
echo GitHub CLI kuruldu ama bu pencere henuz goremiyor.
echo Pencereyi kapatip GITHUB.bat'i bir kez daha calistirin.
pause
exit /b 1

:hata
echo.
echo Bir sorun olustu. Ekrandaki mesaji Claude'a yapistirin.
pause
exit /b 1
