#!/usr/bin/env bash
# Esportazione Windows da Linux: non certifica l'esecuzione Windows.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-godot}"
version="$("$GODOT" --version)"
[[ "$version" == 4.7.2.stable.* ]] || { echo 'Richiesto Godot 4.7.2 stable' >&2; exit 2; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export XDG_DATA_HOME="$work/data"
export XDG_CONFIG_HOME="$work/config"
export XDG_CACHE_HOME="$work/cache"
mkdir -p "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" build/candidata-windows
# Una cache esplicita evita di riscaricare i template nei collaudi locali.
template_archive="${GODOT_TEMPLATES_ARCHIVE:-$work/templates.tpz}"
if [[ ! -f "$template_archive" ]]; then
  curl -fL --retry 3 https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz -o "$template_archive"
fi
unzip -jo "$template_archive" 'templates/windows_release_x86_64*' 'templates/version.txt' -d "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable"
for stage in import export; do
  if [[ "$stage" == import ]]; then
    args=(--editor --import)
  else
    args=(--export-release 'Windows Desktop' build/candidata-windows/UltimoRifugio.exe)
  fi
  if ! "$GODOT" --headless --path . "${args[@]}" >"$work/$stage.log" 2>&1; then
    cat "$work/$stage.log"; exit 1
  fi
  cat "$work/$stage.log"
  if grep -Ei '(ERROR:|Parse Error:|FATAL:)' "$work/$stage.log"; then
    exit 1
  fi
done
python3 - <<'PY'
import pathlib, struct
folder = pathlib.Path('build/candidata-windows')
exe = (folder/'UltimoRifugio.exe').read_bytes()
assert exe[:2] == b'MZ', 'Eseguibile Windows assente'
pe = struct.unpack_from('<I', exe, 0x3c)[0]
assert exe[pe:pe+4] == b'PE\0\0' and struct.unpack_from('<H', exe, pe+4)[0] == 0x8664
assert (folder/'UltimoRifugio.pck').stat().st_size > 100000
(folder/'CANDIDATA_PORTATILE.txt').write_text('Dati di collaudo separati da Alfa 13. Conservare questo file accanto al gioco.\n',encoding='utf-8')
(folder/'AVVIA_CANDIDATA.bat').write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\nstart "" "UltimoRifugio.exe"\r\n')
(folder/'LEGGIMI.txt').write_text(
    'ULTIMO RIFUGIO - CANDIDATA DI COLLAUDO\n'
    'Estrai tutto in una NUOVA cartella e avvia AVVIA_CANDIDATA.bat.\n'
    'Non sostituire la cartella di Alfa 13. Nessun aggiornamento automatico incluso.\n'
    'La candidata usa salvataggi/ accanto al proprio eseguibile.\n'
    'Non sovrascrivere la tua unica copia di una partita.\n'
    'Controlli: WASD, E banco, B costruisci/ripara, clic destro ispeziona, F recupero.\n'
    'F3 apre i comandi di prova per danneggiare/riparare le strutture.\n'
    'COLLAUDO RICHIESTO: soltanto estetico.\n'
    'F3: Simula danni una volta (danneggiato), due volte (grave), tre (crollo).\n'
    'Controlla mura, cancello, rifugio e banco; poi Ripara tutto (test).\n'
    'Verifica che gli stadi si distinguano allo zoom abituale.\n'
    'Le meccaniche gia collaudate restano invariate.\n'
    'Esportata con Godot 4.7.2 da Linux. Avvio Windows da collaudare.\n',encoding='utf-8')
PY
# Carica il PCK esportato con un template release Linux, senza editor.
# Verifica anche che il marcatore separi davvero i dati del collaudo.
unzip -jo "$template_archive" templates/linux_release.x86_64 -d "$work/packed"
chmod +x "$work/packed/linux_release.x86_64"
cp build/candidata-windows/UltimoRifugio.pck "$work/packed/linux_release.pck"
cp build/candidata-windows/CANDIDATA_PORTATILE.txt "$work/packed/"
for stage in packed-start packed-reload; do
  if ! "$work/packed/linux_release.x86_64" --headless --quit-after 15 >"$work/$stage.log" 2>&1; then
    cat "$work/$stage.log"; exit 1
  fi
  cat "$work/$stage.log"
  if grep -Ei '(ERROR:|Parse Error:|FATAL:)' "$work/$stage.log"; then exit 1; fi
  python3 - "$work/packed/salvataggi/partita.json" <<'PYTEST'
import json, sys
with open(sys.argv[1], encoding='utf-8') as stream:
    data = json.load(stream)
assert data['version'] == 8 and 'salvage' in data and 'wall_hp' in data
print('OK: PCK release, dati portatili e salvataggio v8')
PYTEST
done
git rev-parse HEAD > build/candidata-windows/COMMIT.txt
(cd build/candidata-windows && sha256sum UltimoRifugio.exe UltimoRifugio.pck > SHA256SUMS.txt)
echo 'OK: esportazione Windows x86_64 e pacchetto di collaudo pronti.'
