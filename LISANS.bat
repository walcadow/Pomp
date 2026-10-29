@echo off
chcp 65001 >nul
title Pomp - Android lisanslari
set "PATH=%USERPROFILE%\Desktop\flutter\bin;%PATH%"
echo Her soruda  y  yazip Enter'a basin.
echo.
call flutter doctor --android-licenses
echo.
echo Bitti. Bu pencereyi kapatabilirsiniz.
pause
