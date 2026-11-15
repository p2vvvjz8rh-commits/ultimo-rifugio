$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Log = Join-Path $PSScriptRoot 'log_aggiornamenti.txt'
$ConfigPath = Join-Path $PSScriptRoot 'config.txt'
$LocalVersion = Join-Path $PSScriptRoot 'ultimo_commit.txt'
$Temp = Join-Path $env:TEMP ('UltimoRifugio_Update_' + [Guid]::NewGuid().ToString('N'))
function Log([string]$s) { $line = ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$s); Write-Host $s; Add-Content -LiteralPath $Log -Value $line -Encoding UTF8 }
function LaunchGame {
  $exe = Join-Path $Root 'build\UltimoRifugio.exe'
  if (Test-Path -LiteralPath $exe) { Log 'Avvio il gioco gia installato.'; Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe); return }
  $bat = Join-Path $Root 'AVVIA_O_CREA_GIOCO.bat'
  if (Test-Path -LiteralPath $bat) { Log 'Avvio la procedura di compilazione iniziale.'; Start-Process -FilePath $bat -WorkingDirectory $Root; return }
  throw 'Non trovo ne il gioco ne il file AVVIA_O_CREA_GIOCO.bat.'
}
try {
  Log '=== AGGIORNA E GIOCA - Ultimo Rifugio ==='
  if (!(Test-Path -LiteralPath $ConfigPath)) { throw 'Manca aggiornamenti\config.txt.' }
  $config = @{}
  Get-Content -LiteralPath $ConfigPath | ForEach-Object { if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') { $config[$matches[1]] = $matches[2] } }
  $repo = [string]$config['REPOSITORY']; $branch = [string]$config['BRANCH']
  if (!$branch) { $branch='main' }
  if ($repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or $repo -eq 'esempio/ultimo-rifugio') {
    Log 'Manca il repository GitHub: configura REPOSITORY in aggiornamenti\config.txt.'
    LaunchGame
    exit 0
  }
  if ((Get-Process -Name 'UltimoRifugio' -ErrorAction SilentlyContinue)) {
    Log 'Chiudi Ultimo Rifugio prima di aggiornare; avvio la copia esistente senza modifiche.'
    exit 1
  }
  $headers = @{ 'User-Agent'='Ultimo-Rifugio-Updater'; 'Accept'='application/vnd.github+json' }
  $encodedBranch = [Uri]::EscapeDataString($branch)
  $metaUrl = "https://api.github.com/repos/$repo/commits/$encodedBranch"
  try {
    $metadata = Invoke-RestMethod -Uri $metaUrl -Headers $headers -TimeoutSec 35
    $remote = [string]$metadata.sha
    if ($remote -notmatch '^[a-fA-F0-9]{40}$') { throw 'Risposta GitHub non valida' }
  } catch {
    Log ('Non riesco a raggiungere il repository: ' + $_.Exception.Message)
    Log 'Il gioco locale non viene modificato.'
    LaunchGame
    exit 0
  }
  $old = if (Test-Path -LiteralPath $LocalVersion) { (Get-Content -LiteralPath $LocalVersion -Raw).Trim() } else { '' }
  if ($old -eq $remote) { Log 'Nessun aggiornamento disponibile.'; LaunchGame; exit 0 }
  Log 'Nuova versione trovata. Scarico soltanto se il repository e configurato correttamente.'
  New-Item -ItemType Directory -Path $Temp | Out-Null
  $archive = Join-Path $Temp 'source.zip'
  $extract = Join-Path $Temp 'estratto'
  $zipUrl = "https://api.github.com/repos/$repo/zipball/$remote"
  Invoke-WebRequest -Uri $zipUrl -Headers $headers -OutFile $archive -TimeoutSec 180 -MaximumRedirection 6 | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($archive,$extract)
  $dirs = @(Get-ChildItem -LiteralPath $extract -Directory)
  if ($dirs.Count -ne 1) { throw 'Archivio GitHub inatteso: nessuna cartella principale univoca.' }
  $src = $dirs[0].FullName
  if (!(Test-Path -LiteralPath (Join-Path $src 'project.godot')) -or !(Test-Path -LiteralPath (Join-Path $src 'scripts\world.gd'))) {
    throw 'Il repository non contiene un progetto Godot valido nella radice. Nessun file del gioco e stato modificato.'
  }
  # Backup dei soli file che saranno sostituiti, senza toccare salvataggi e Godot portatile.
  $backup = Join-Path $Root ('aggiornamenti\backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  $files = @(Get-ChildItem -LiteralPath $src -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($src.Length).TrimStart([char]92,[char]47)
    $rel -notmatch '^(?i)(\.git[\\/]|\.godot[\\/]|\.godot_portatile[\\/]|build[\\/]|aggiornamenti[\\/]|\.github[\\/])' -and $rel -notmatch '^(?i)(AGGIORNA_E_GIOCA\.bat|AVVIA_O_CREA_GIOCO\.bat)$'
  })
  if ($files.Count -eq 0) { throw 'Archivio privo di file aggiornabili.' }
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($src.Length).TrimStart([char]92,[char]47)
    $target = Join-Path $Root $rel
    if (Test-Path -LiteralPath $target) {
      $b = Join-Path $backup $rel
      New-Item -ItemType Directory -Path (Split-Path $b -Parent) -Force | Out-Null
      Copy-Item -LiteralPath $target -Destination $b -Force
    }
  }
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($src.Length).TrimStart([char]92,[char]47)
    $target = Join-Path $Root $rel
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $f.FullName -Destination $target -Force
  }
  # Rebuild all'avvio per le modifiche agli script: un marker forza il BAT esistente a ricompilare.
  $marker = Join-Path $Root 'build\patch_orientamento_collisioni_applicata.txt'
  if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
  Set-Content -LiteralPath $LocalVersion -Value $remote -Encoding ASCII
  Log ("Aggiornati {0} file. Backup: {1}" -f $files.Count,$backup)
  $bat = Join-Path $Root 'AVVIA_O_CREA_GIOCO.bat'
  if (!(Test-Path -LiteralPath $bat)) { throw 'Manca AVVIA_O_CREA_GIOCO.bat.' }
  Log 'Avvio la ricompilazione e il gioco.'
  Start-Process -FilePath $bat -WorkingDirectory $Root
} catch {
  Log ('ERRORE: ' + $_.Exception.Message)
  Log 'Il gioco esistente e i salvataggi rimangono nella cartella. Vedi il log.'
  exit 1
} finally {
  if (Test-Path -LiteralPath $Temp) { Remove-Item -LiteralPath $Temp -Recurse -Force -ErrorAction SilentlyContinue }
}
