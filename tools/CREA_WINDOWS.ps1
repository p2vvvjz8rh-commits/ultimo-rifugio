param([switch]$Avvia)
# Ultimo Rifugio Alfa 08 - build portatile Windows, correzione 1.
# Esegui tramite AVVIA_O_CREA_GIOCO.bat dalla cartella del progetto.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ToolsCache = Join-Path $Project '.godot_portatile'
$Build = Join-Path $Project 'build'
$EngineFolder = Join-Path $ToolsCache 'engine'
$EngineZip = Join-Path $ToolsCache 'godot_win64.zip'
$TemplateDownload = Join-Path $ToolsCache 'godot_export_templates.tpz'
$TemplateZip = Join-Path $ToolsCache 'godot_export_templates.zip'
$Version = '4.7.2'
$TemplateDestination = Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable'
$EngineUrl = "https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=$Version"
$TemplateUrl = "https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=$Version"
New-Item -ItemType Directory -Force -Path $ToolsCache, $Build, $EngineFolder | Out-Null
$Log = Join-Path $Build 'log_build.txt'
$ImportOut = Join-Path $Build 'import_stdout.txt'
$ImportErr = Join-Path $Build 'import_stderr.txt'
$TestOut = Join-Path $Build 'test_stdout.txt'
$TestErr = Join-Path $Build 'test_stderr.txt'
$ExportOut = Join-Path $Build 'export_stdout.txt'
$ExportErr = Join-Path $Build 'export_stderr.txt'
'ULTIMO RIFUGIO - Alfa 08 - diagnosi build corretta' | Set-Content $Log -Encoding UTF8
('Data: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) | Add-Content $Log -Encoding UTF8
('Progetto: ' + $Project) | Add-Content $Log -Encoding UTF8

function Report([string]$message) {
    Write-Host $message
    Add-Content -Path $Log -Value $message -Encoding UTF8
}
function Download-IfMissing([string]$Url, [string]$Path) {
    if ((Test-Path $Path) -and (Get-Item $Path).Length -gt 1000000) { return }
    Report ('Download: ' + $Url)
    Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing -MaximumRedirection 8
    if ((Get-Item $Path).Length -lt 1000000) { throw "Download incompleto: $Path" }
}
function Run-Godot([string]$ConsoleExe, [string]$Stage, [string]$Arguments, [string]$Out, [string]$Err) {
    Report ('== ' + $Stage + ' ==')
    Report ('Comando: ' + $ConsoleExe + ' ' + $Arguments)
    # Start-Process -Wait -PassThru attende davvero il processo Windows
    # e restituisce sempre un ExitCode verificabile, a differenza di & sul GUI editor.
    $process = Start-Process -FilePath $ConsoleExe -ArgumentList $Arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput $Out -RedirectStandardError $Err
    if ($null -eq $process) { throw ('Godot non ha restituito un processo per: ' + $Stage) }
    $code = [int]$process.ExitCode
    Report ('Codice di uscita ' + $Stage + ': ' + $code)
    foreach ($path in @($Out, $Err)) {
        if (Test-Path $path) {
            Add-Content -Path $Log -Value ('--- ' + [IO.Path]::GetFileName($path) + ' ---') -Encoding UTF8
            Get-Content -Path $path -ErrorAction SilentlyContinue | Add-Content -Path $Log -Encoding UTF8
        }
    }
    if ($code -ne 0) { throw ("Godot: $Stage non riuscito (codice $code). Controlla build\log_build.txt.") }
    # Il motore a volte chiude con codice 0 nonostante errori di parsing.
    $errors = @(Select-String -Path $Out, $Err -Pattern 'SCRIPT ERROR:','Parse Error:','ERROR: Failed loading resource','ERROR: Failed to load script','ERROR: Cannot load' -ErrorAction SilentlyContinue)
    if ($errors.Count -gt 0) {
        $sample = ($errors | Select-Object -First 4 | ForEach-Object { $_.Line }) -join ' | '
        throw ("Godot segnala errori in $Stage`: $sample. Vedi build\log_build.txt.")
    }
}

try {
    Report 'Cerco Godot 4.7.2 portatile...'
    $Editor = Get-ChildItem -Path $EngineFolder -Recurse -File -Filter 'Godot*win64*.exe' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'console' } | Select-Object -First 1
    if (-not $Editor) {
        Download-IfMissing $EngineUrl $EngineZip
        Report 'Estraggo Godot...'
        Expand-Archive -LiteralPath $EngineZip -DestinationPath $EngineFolder -Force
        $Editor = Get-ChildItem -Path $EngineFolder -Recurse -File -Filter 'Godot*win64*.exe' |
            Where-Object { $_.Name -notmatch 'console' } | Select-Object -First 1
    }
    if (-not $Editor) { throw 'Editor Godot Windows non trovato dopo estrazione.' }
    $ConsoleExe = Join-Path $Editor.Directory.FullName ($Editor.BaseName + '_console.exe')
    if (-not (Test-Path $ConsoleExe)) {
        $ConsoleExe = (Get-ChildItem -Path $Editor.Directory.FullName -Filter '*console.exe' -File | Select-Object -First 1 -ExpandProperty FullName)
    }
    if (-not $ConsoleExe -or -not (Test-Path $ConsoleExe)) { throw 'Eseguibile console di Godot mancante. Riestrai lo ZIP ufficiale completo.' }
    Report ('Godot console trovato: ' + $ConsoleExe)
    # Le virgolette sul percorso sono fondamentali se la cartella Windows contiene spazi.
    $QuotedProject = '"' + $Project + '"'
    Run-Godot $ConsoleExe 'IMPORTAZIONE' ('--headless --path ' + $QuotedProject + ' --editor --import') $ImportOut $ImportErr
    Run-Godot $ConsoleExe 'CONTROLLO SCENA' ('--headless --path ' + $QuotedProject + ' --quit-after 3') $TestOut $TestErr

    # Scarica i template SOLO dopo che l'importazione e il controllo sono riusciti.
    $TemplateExe = Join-Path $TemplateDestination 'windows_release_x86_64.exe'
    if (-not (Test-Path $TemplateExe)) {
        Download-IfMissing $TemplateUrl $TemplateDownload
        # I template Godot sono un archivio ZIP con estensione .tpz.
        # Expand-Archive su PowerShell 5.1 accetta soltanto estensione .zip.
        Copy-Item -LiteralPath $TemplateDownload -Destination $TemplateZip -Force
        $Temp = Join-Path $ToolsCache 'templates_estratti'
        New-Item -ItemType Directory -Force -Path $Temp | Out-Null
        Expand-Archive -LiteralPath $TemplateZip -DestinationPath $Temp -Force
        $Found = Get-ChildItem -Path $Temp -Recurse -Filter 'windows_release_x86_64.exe' -File | Select-Object -First 1
        if (-not $Found) { throw 'Template Windows x86_64 non trovato nel pacchetto ufficiale.' }
        New-Item -ItemType Directory -Force -Path $TemplateDestination | Out-Null
        Copy-Item -Path (Join-Path $Found.Directory.FullName '*') -Destination $TemplateDestination -Recurse -Force
    }
    $GameExe = Join-Path $Build 'UltimoRifugio.exe'
    $ExportArgs = '--headless --path ' + $QuotedProject + ' --export-release "Windows Desktop" "' + $GameExe + '"'
    Run-Godot $ConsoleExe 'ESPORTAZIONE' $ExportArgs $ExportOut $ExportErr
    if (-not (Test-Path $GameExe)) { throw 'Godot non ha creato build\UltimoRifugio.exe.' }
    if ((Get-Item $GameExe).Length -lt 1000000) { throw 'EXE Windows troppo piccolo: esportazione non valida.' }
    New-Item -ItemType Directory -Force -Path (Join-Path $Build 'salvataggi') | Out-Null
    Copy-Item -Path (Join-Path $Project 'docs\LICENSE_QUATERNIUS.txt') -Destination $Build -Force
    $PortableZip = Join-Path $Project 'Ultimo_Rifugio_Alfa08_Windows_Portatile.zip'
    if (Test-Path $PortableZip) { Remove-Item $PortableZip -Force }
    # Zip giocabile senza file diagnostici.
    $ToPackage = @($GameExe, (Join-Path $Build 'salvataggi'), (Join-Path $Build 'LICENSE_QUATERNIUS.txt'))
    $Pck = Join-Path $Build 'UltimoRifugio.pck'
    if (Test-Path $Pck) { $ToPackage += $Pck }
    Compress-Archive -Path $ToPackage -DestinationPath $PortableZip -CompressionLevel Optimal
    Report ('SUCCESSO: ' + $GameExe)
    Report ('ZIP portatile: ' + $PortableZip)
    if ($Avvia) { Start-Process -FilePath $GameExe -WorkingDirectory $Build }
    exit 0
} catch {
    Report ('ERRORE: ' + $_.Exception.Message)
    Report ('DETTAGLI: ' + $_.ToString())
    Write-Host ''
    Write-Host ('Impossibile completare. Invia il file: ' + $Log) -ForegroundColor Red
    exit 1
}
