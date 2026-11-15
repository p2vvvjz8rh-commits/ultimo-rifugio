# Ultimo Rifugio: aggiornatore Windows. Non modifica salvataggi o Godot portatile.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Log = Join-Path $PSScriptRoot 'log_aggiornamenti.txt'
$ConfigPath = Join-Path $PSScriptRoot 'config.txt'
$StampPath = Join-Path $PSScriptRoot 'ultimo_commit.txt'
$GameExe = Join-Path $Root 'build\UltimoRifugio.exe'
$Work = Join-Path $env:TEMP ('UltimoRifugio_' + [guid]::NewGuid().ToString('N'))
function Say([string]$Message) {
    Write-Host $Message
    Add-Content -LiteralPath $Log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Message) -Encoding UTF8
}
function Start-Game {
    if (!(Test-Path -LiteralPath $GameExe)) { throw 'Eseguibile del gioco mancante.' }
    Say 'Avvio Ultimo Rifugio.'
    Start-Process -FilePath $GameExe -WorkingDirectory (Join-Path $Root 'build')
}
function Build-Game {
    $Script = Join-Path $Root 'tools\CREA_WINDOWS.ps1'
    if (!(Test-Path -LiteralPath $Script)) { throw 'Procedura Godot mancante.' }
    Say 'Compilo la nuova versione. Questa operazione puo richiedere qualche minuto.'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script
    $Code = $LASTEXITCODE
    if ($Code -ne 0 -or !(Test-Path -LiteralPath $GameExe)) {
        throw "Compilazione non riuscita (codice $Code). Vedi build\log_build.txt."
    }
}
function Rollback([string]$Backup, [string[]]$Changed, [string[]]$Created) {
    Say 'Ripristino i file precedenti.'
    foreach ($Rel in $Created) {
        $Dest = Join-Path $Root $Rel
        if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Force -ErrorAction SilentlyContinue }
    }
    foreach ($Rel in $Changed) {
        $Old = Join-Path $Backup ('source\' + $Rel)
        if (Test-Path -LiteralPath $Old) {
            $Dest = Join-Path $Root $Rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $Dest) -Force | Out-Null
            Copy-Item -LiteralPath $Old -Destination $Dest -Force
        }
    }
    foreach ($Name in @('UltimoRifugio.exe','UltimoRifugio.pck')) {
        $Old = Join-Path $Backup ('build\' + $Name)
        if (Test-Path -LiteralPath $Old) { Copy-Item -LiteralPath $Old -Destination (Join-Path $Root ('build\' + $Name)) -Force }
    }
}
$Backup = $null
$Changed = @()
$Created = @()
$Touched = $false
try {
    Say '===== ULTIMO RIFUGIO - AGGIORNAMENTO AUTOMATICO ====='
    if (Get-Process -Name UltimoRifugio -ErrorAction SilentlyContinue) {
        throw 'Il gioco e ancora aperto. Chiudilo prima di aggiornare.'
    }
    if (!(Test-Path -LiteralPath $ConfigPath)) { throw 'Configurazione GitHub mancante.' }
    $Cfg = @{}
    Get-Content -LiteralPath $ConfigPath | ForEach-Object {
        if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') { $Cfg[$matches[1]] = $matches[2] }
    }
    $Repo = [string]$Cfg.REPOSITORY
    $Branch = [string]$Cfg.BRANCH
    if (!$Branch) { $Branch = 'main' }
    if ($Repo -notmatch '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' -or $Branch -notmatch '^[a-zA-Z0-9._/-]+$') {
        throw 'Indirizzo del repository o branch non valido.'
    }
    $Headers = @{ 'User-Agent'='Ultimo-Rifugio-Launcher'; 'Accept'='application/vnd.github+json' }
    Say 'Controllo la versione disponibile su GitHub...'
    try {
        $Meta = Invoke-RestMethod -Uri ("https://api.github.com/repos/$Repo/commits/" + [uri]::EscapeDataString($Branch)) -Headers $Headers -TimeoutSec 30
        $Remote = [string]$Meta.sha
        if ($Remote -notmatch '^[0-9a-fA-F]{40}$') { throw 'Risposta senza versione valida.' }
    } catch {
        Say ('GitHub non raggiungibile: ' + $_.Exception.Message)
        if (Test-Path -LiteralPath $GameExe) { Say 'Uso la versione gia installata.'; Start-Game; exit 0 }
        throw 'Non c e un gioco installato utilizzabile offline.'
    }
    $Installed = if (Test-Path -LiteralPath $StampPath) { (Get-Content -LiteralPath $StampPath -Raw).Trim() } else { '' }
    if ($Installed -eq $Remote -and (Test-Path -LiteralPath $GameExe)) {
        Say 'Gioco gia aggiornato.'
        Start-Game
        exit 0
    }
    Say ('Versione remota: ' + $Remote.Substring(0,10) + '. Scarico l aggiornamento...')
    New-Item -ItemType Directory -Path $Work -Force | Out-Null
    $Zip = Join-Path $Work 'progetto.zip'
    $Extract = Join-Path $Work 'estratto'
    Invoke-WebRequest -Uri "https://api.github.com/repos/$Repo/zipball/$Remote" -Headers $Headers -OutFile $Zip -TimeoutSec 180 -MaximumRedirection 8 -UseBasicParsing | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip,$Extract)
    $Top = @(Get-ChildItem -LiteralPath $Extract -Directory)
    if ($Top.Count -ne 1) { throw 'Formato archivio GitHub inatteso.' }
    $Source = $Top[0].FullName
    if (!(Test-Path -LiteralPath (Join-Path $Source 'project.godot')) -or !(Test-Path -LiteralPath (Join-Path $Source 'scripts\world.gd'))) {
        throw 'Il progetto scaricato non e valido.'
    }
    $Files = @(Get-ChildItem -LiteralPath $Source -Recurse -File | Where-Object {
        $Rel = $_.FullName.Substring($Source.Length).TrimStart([char]92,[char]47)
        ($Rel -match '^(scripts|scenes|assets|docs|tools)[\\/]') -or
        ($Rel -match '^(project\.godot|export_presets\.cfg|VERSIONE\.txt)$')
    })
    if ($Files.Count -lt 4) { throw 'Sorgenti incompleti: aggiornamento annullato.' }
    $Backup = Join-Path $PSScriptRoot ('backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Path (Join-Path $Backup 'source') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Backup 'build') -Force | Out-Null
    foreach ($Name in @('UltimoRifugio.exe','UltimoRifugio.pck')) {
        $Original = Join-Path $Root ('build\' + $Name)
        if (Test-Path -LiteralPath $Original) { Copy-Item -LiteralPath $Original -Destination (Join-Path $Backup ('build\' + $Name)) -Force }
    }
    foreach ($File in $Files) {
        $Rel = $File.FullName.Substring($Source.Length).TrimStart([char]92,[char]47)
        $Dest = Join-Path $Root $Rel
        if (Test-Path -LiteralPath $Dest) {
            $OriginalCopy = Join-Path $Backup ('source\' + $Rel)
            New-Item -ItemType Directory -Path (Split-Path -Parent $OriginalCopy) -Force | Out-Null
            Copy-Item -LiteralPath $Dest -Destination $OriginalCopy -Force
            $Changed += $Rel
        } else { $Created += $Rel }
    }
    $Touched = $true
    foreach ($File in $Files) {
        $Rel = $File.FullName.Substring($Source.Length).TrimStart([char]92,[char]47)
        $Dest = Join-Path $Root $Rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $Dest) -Force | Out-Null
        Copy-Item -LiteralPath $File.FullName -Destination $Dest -Force
    }
    Say ("Applicati $($Files.Count) file sorgente. Verifico la compilazione...")
    Build-Game
    Set-Content -LiteralPath $StampPath -Value $Remote -Encoding ASCII
    Say 'Aggiornamento completato. I salvataggi non sono stati modificati.'
    Start-Game
} catch {
    Say ('ERRORE: ' + $_.Exception.Message)
    if ($Touched -and $Backup) {
        try { Rollback $Backup $Changed $Created; Say 'Ripristino completato; la vecchia versione resta utilizzabile.' }
        catch { Say ('ATTENZIONE: ripristino incompleto: ' + $_.Exception.Message) }
    }
    Say 'Per assistenza invia aggiornamenti\log_aggiornamenti.txt e build\log_build.txt.'
    exit 1
} finally {
    if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue }
}
