#!/usr/bin/env bash
# Godot headless - controlli preliminari del progetto, NON rendering interattivo.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1 && [[ ! -x "$GODOT" ]]; then
  echo "Godot non trovato: imposta GODOT_BIN alla sua posizione." >&2
  exit 2
fi
if [[ ! -f project.godot || ! -f scenes/World.tscn ]]; then
  echo "Mancano i sorgenti principali del progetto." >&2
  exit 2
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# Usa un HOME temporaneo, per non leggere o sovrascrivere salvataggi locali.
export HOME="$work/home"
export XDG_DATA_HOME="$work/xdg-data"
export XDG_CONFIG_HOME="$work/xdg-config"
export XDG_CACHE_HOME="$work/xdg-cache"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
echo "== Godot: versione =="
"$GODOT" --version
echo "== Godot: importazione asset =="
if ! "$GODOT" --headless --path . --editor --import >"$work/import.log" 2>&1; then
  cat "$work/import.log"; exit 1
fi
cat "$work/import.log"
echo "== Godot: scena e chiusura (15 frame) =="
if ! "$GODOT" --headless --path . --quit-after 15 >"$work/scene.log" 2>&1; then
  cat "$work/scene.log"; exit 1
fi
cat "$work/scene.log"
if grep -E -i '(SCRIPT ERROR:|Parse Error:|Invalid access to property|ERROR: Failed loading resource|ERROR: Failed to load script|ERROR: Cannot load)' "$work/import.log" "$work/scene.log"; then
  echo "Controllo fallito: errori di script o risorse rilevati." >&2
  exit 1
fi
echo "OK: importazione e avvio headless senza errori noti."
