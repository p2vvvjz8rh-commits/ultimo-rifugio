@echo off
setlocal
cd /d "%~dp0"
rem ALFA 08: la patch orientamento/collisioni richiede un rebuild UNA VOLTA.
if exist "build\UltimoRifugio.exe" if exist "build\patch_orientamento_collisioni_applicata.txt" (
    echo Avvio Ultimo Rifugio 3D aggiornato...
    start "" "build\UltimoRifugio.exe"
    exit /b 0
)
echo.
echo ==========================================================
echo ULTIMO RIFUGIO - CORREZIONE ROTAZIONE E PALIZZATA
echo ==========================================================
echo Primo avvio dopo la patch: ricompilo il gioco.
echo Il salvataggio in build\salvataggi non viene modificato.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\CREA_WINDOWS.ps1" -Avvia
if errorlevel 1 (
    echo.
    echo ERRORE durante la compilazione. Consulta build\log_build.txt
    pause
    exit /b 1
)
if not exist "build\UltimoRifugio.exe" (
    echo ERRORE: il nuovo eseguibile non e' stato generato.
    pause
    exit /b 1
)
echo Patch collisioni compilata.> "build\patch_orientamento_collisioni_applicata.txt"
endlocal
