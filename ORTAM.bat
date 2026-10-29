@echo off
set "LOG=%~dp0ortam_log.txt"
echo ===== DOCKER ===== > "%LOG%"
where docker >> "%LOG%" 2>&1
docker version >> "%LOG%" 2>&1
docker compose version >> "%LOG%" 2>&1
echo ===== NODE ===== >> "%LOG%"
where node >> "%LOG%" 2>&1
echo ===== DOCKER DESKTOP ===== >> "%LOG%"
dir "C:\Program Files\Docker\Docker\Docker Desktop.exe" >> "%LOG%" 2>&1
echo ===== BITTI ===== >> "%LOG%"
