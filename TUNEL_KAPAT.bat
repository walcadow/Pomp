@echo off
cd /d "%~dp0"
docker compose --profile tunnel stop tunnel
docker compose --profile tunnel rm -f tunnel
echo Tunel kapatildi. Sunucu yalnizca bu bilgisayardan erisilebilir.
pause
