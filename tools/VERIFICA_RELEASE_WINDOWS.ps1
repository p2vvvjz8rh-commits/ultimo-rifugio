param([Parameter(Mandatory=$true)][string]$Package)
# Solo runner effimero: include una prova sul percorso storico Windows.
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Questo controllo usa solo runner CI effimeri, non il PC del giocatore.' }
$Folder = (Resolve-Path -LiteralPath $Package).Path
$Exe = Join-Path $Folder 'UltimoRifugio.exe'
$Marker = Join-Path $Folder 'PORTATILE.txt'
if (!(Test-Path -LiteralPath $Marker) -or (Test-Path -LiteralPath (Join-Path $Folder 'CANDIDATA_PORTATILE.txt'))) { throw 'Pacchetto stabile non valido.' }
$Tokens = $null
$ParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'CREA_WINDOWS.ps1'),[ref]$Tokens,[ref]$ParseErrors) | Out-Null
if ($ParseErrors.Count -gt 0) { throw 'Sintassi del builder Windows non valida.' }
$Fixture = @{version=8;wood=77;coins=31;hp=83;px=1;pz=2;stockade_built=$true;gate_hp=140;bench_hp=100;wall_hp=@(120,240,240,240,240,240,240,240,240);defense_hp_scale=240;elapsed=10;next_raid=240}
$Utf8 = New-Object System.Text.UTF8Encoding($false)
function Test-Save([string]$Save) {
    $Data = Get-Content -LiteralPath $Save -Raw | ConvertFrom-Json
    if ($Data.version -ne 8 -or $Data.game_release -ne 'alfa14' -or $Data.wood -ne 77 -or $Data.coins -ne 31 -or $Data.gate_hp -ne 140 -or $Data.wall_hp[0] -ne 120) { throw 'Progresso Alfa 13 non conservato.' }
    if ($null -eq $Data.salvage) { throw 'Campi opzionali mancanti.' }
}
function Run-Release([string]$Stage) {
    $Out = Join-Path $env:RUNNER_TEMP ($Stage + '-out.log')
    $Err = Join-Path $env:RUNNER_TEMP ($Stage + '-err.log')
    $Process = Start-Process -FilePath $Exe -WorkingDirectory $Folder -ArgumentList '--headless --audio-driver Dummy --quit-after 15' -Wait -PassThru -RedirectStandardOutput $Out -RedirectStandardError $Err
    Get-Content $Out, $Err
    if ($Process.ExitCode -ne 0) { throw "Avvio release fallito: $Stage" }
    if (Select-String -Path $Out,$Err -Pattern 'ERROR:|Parse Error:|FATAL:') { throw 'Errori Godot nella release.' }
    if (!(Select-String -Path $Out -Pattern 'ALFA 14' -SimpleMatch)) { throw 'Il pacchetto non si identifica come Alfa 14.' }
}
$PortableSaves = Join-Path $Folder 'salvataggi'
New-Item -ItemType Directory -Force $PortableSaves | Out-Null
$PortableSave = Join-Path $PortableSaves 'partita.json'
[System.IO.File]::WriteAllText($PortableSave,($Fixture | ConvertTo-Json -Depth 8),$Utf8)
$Before = (Get-FileHash -LiteralPath $PortableSave -Algorithm SHA256).Hash
Run-Release 'portatile-primo-avvio'
Test-Save $PortableSave
if ((Get-FileHash -LiteralPath (Join-Path $PortableSaves 'partita_pre_alfa14.json') -Algorithm SHA256).Hash -ne $Before) { throw 'Backup portatile diverso dalla partita originale.' }
Run-Release 'portatile-riapertura'
Test-Save $PortableSave
if (@(Get-ChildItem -LiteralPath $PortableSaves -Filter 'partita_pre_alfa14*.json').Count -ne 1) { throw 'Backup duplicato senza migrazione.' }
# Senza marcatore portatile la release deve ritrovare la vecchia cartella di Alfa 13.
Move-Item -LiteralPath $Marker -Destination (Join-Path $Folder 'PORTATILE.disattivato')
$HistoricalSaves = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Godot\app_userdata\Ultimo Rifugio - Alfa 13\salvataggi'
New-Item -ItemType Directory -Force $HistoricalSaves | Out-Null
$HistoricalSave = Join-Path $HistoricalSaves 'partita.json'
if (Test-Path -LiteralPath $HistoricalSave) { throw 'Il runner non e effimero: partita preesistente, controllo interrotto.' }
[System.IO.File]::WriteAllText($HistoricalSave,($Fixture | ConvertTo-Json -Depth 8),$Utf8)
$HistoricalBefore = (Get-FileHash -LiteralPath $HistoricalSave -Algorithm SHA256).Hash
$PortableBefore = (Get-FileHash -LiteralPath $PortableSave -Algorithm SHA256).Hash
Run-Release 'percorso-storico-alfa13'
Test-Save $HistoricalSave
if ((Get-FileHash -LiteralPath (Join-Path $HistoricalSaves 'partita_pre_alfa14.json') -Algorithm SHA256).Hash -ne $HistoricalBefore) { throw 'Backup storico non valido.' }
if ((Get-FileHash -LiteralPath $PortableSave -Algorithm SHA256).Hash -ne $PortableBefore) { throw 'La modalita normale ha modificato la partita portatile.' }
Run-Release 'storico-riapertura'
Test-Save $HistoricalSave
Write-Host 'OK: Alfa 14 Windows, backup esatto, progressi v8, portatile e percorso storico Alfa 13 verificati.'
