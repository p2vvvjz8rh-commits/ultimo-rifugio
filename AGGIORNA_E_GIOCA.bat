@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0aggiornamenti\AGGIORNA_E_GIOCA.ps1"
if errorlevel 1 (
  echo.
  echo Aggiornamento o avvio non riuscito. Controlla aggiornamenti\log_aggiornamenti.txt
  pause
)
endlocal
