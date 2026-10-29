@echo off
chcp 65001 >nul
title Pomp - Demo kullanicilar
set "LOG=%~dp0demo_log.txt"
cd /d "%~dp0"
echo Once uygulamada kayit olup fotograf eklediginizden ve konum izni verdiginizden emin olun.
echo.
docker compose exec -T api npm run seed > "%LOG%" 2>&1
type "%LOG%"
echo.
pause
