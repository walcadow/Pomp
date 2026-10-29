@echo off
chcp 65001 >nul
title Pomp - Flutter kurulumu
set "FLUTTER_BIN=%USERPROFILE%\Desktop\flutter\bin"
set "LOG=%~dp0kurulum_log.txt"

if not exist "%FLUTTER_BIN%\flutter.bat" (
  echo HATA: Flutter bulunamadi: %FLUTTER_BIN%
  echo Flutter klasorunun Masaustu\flutter konumunda oldugundan emin olun.
  pause
  exit /b 1
)
set "PATH=%FLUTTER_BIN%;%PATH%"
cd /d "%~dp0mobile"
echo Pomp kurulum kaydi > "%LOG%"

echo.
echo [1/4] Flutter ilk kez hazirlaniyor. Bu adim 5-10 dakika surebilir, pencereyi kapatmayin...
call flutter --disable-analytics >> "%LOG%" 2>&1
call flutter --version >> "%LOG%" 2>&1 || goto hata

echo [2/4] Android ve iOS proje dosyalari olusturuluyor...
call flutter create --org com.walcadow --project-name pomp --platforms android,ios . >> "%LOG%" 2>&1 || goto hata

echo [3/4] Uygulamanin paketleri indiriliyor...
call flutter pub get >> "%LOG%" 2>&1 || goto hata

echo [4/4] Bilgisayar kontrol ediliyor (flutter doctor)...
echo. >> "%LOG%"
echo ===== FLUTTER DOCTOR ===== >> "%LOG%"
call flutter doctor -v >> "%LOG%" 2>&1
echo.
call flutter doctor

echo.
echo ============================================================
echo  Kurulum bitti. Yukarida kirmizi X olan satirlar varsa
echo  Claude'a "kurulum bitti" yazin, kayit dosyasini okuyup
echo  sonraki adimi soyleyecek.
echo ============================================================
pause
exit /b 0

:hata
echo.
echo Bir hata olustu. Ayrintilar: %LOG%
echo Claude'a "hata verdi" yazmaniz yeterli, kayit dosyasini okuyacak.
pause
exit /b 1
