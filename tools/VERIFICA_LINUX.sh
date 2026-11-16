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
# Usa directory XDG temporanee per isolare i salvataggi.
export XDG_DATA_HOME="$work/xdg-data"
export XDG_CONFIG_HOME="$work/xdg-config"
export XDG_CACHE_HOME="$work/xdg-cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
echo "== Godot: versione =="
engine_version="$("$GODOT" --version)"
echo "$engine_version"
if [[ "$engine_version" != 4.7.2.stable.* ]]; then
  echo "Richiesto Godot 4.7.2 stable." >&2
  exit 2
fi
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
echo "== Salvataggio: validita' file partita.json =="
SAVE_PATH="$(find "$XDG_DATA_HOME" -type f -name partita.json -print -quit)"
if [[ -z "$SAVE_PATH" ]]; then
  echo "Il gioco non ha scritto partita.json nella directory dati isolata." >&2
  exit 1
fi
python3 - "$SAVE_PATH" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as stream:
    data = json.load(stream)
assert data.get("version") == 8, "Versione salvataggio inattesa"
for key in ("px", "pz", "hp", "wood", "coins", "base_hp", "gate_hp", "bench_hp", "wall_hp"):
    assert key in data, f"Campo di salvataggio mancante: {key}"
assert isinstance(data["wall_hp"], list), "wall_hp non e' un array"
print("OK: salvataggio JSON valido e completo")
PY
echo "== Godot: riapertura del salvataggio =="
if ! "$GODOT" --headless --path . --quit-after 15 >"$work/reload.log" 2>&1; then
  cat "$work/reload.log"; exit 1
fi
cat "$work/reload.log"
if grep -E -i '(ERROR:|Parse Error:|Invalid access to property|FATAL:)' "$work/import.log" "$work/scene.log" "$work/reload.log"; then
  echo "Controllo fallito: errori di script o risorse rilevati." >&2
  exit 1
fi
echo "OK: importazione, avvio, salvataggio JSON e riapertura senza errori noti."

echo "== Godot: regressioni manutenzione e salvataggi legacy =="
if ! "$GODOT" --headless --path . --script tests/base_maintenance.gd >"$work/maintenance.log" 2>&1; then
  cat "$work/maintenance.log"; exit 1
fi
cat "$work/maintenance.log"
if grep -E -i '(ERROR:|Parse Error:|Invalid access to property|FATAL:)' "$work/maintenance.log"; then
  exit 1
fi

echo "== Godot: regressioni esplorazione e deterioramento =="
if ! "$GODOT" --headless --path . --script tests/exploration_and_damage.gd >"$work/exploration.log" 2>&1; then
  cat "$work/exploration.log"; exit 1
fi
cat "$work/exploration.log"
if grep -E -i '(ERROR:|Parse Error:|Invalid access to property|FATAL:)' "$work/exploration.log"; then
  exit 1
fi

echo "== Godot: geometria dei tre stati e crollo =="
if ! "$GODOT" --headless --path . --script tests/structure_geometry.gd >"$work/geometry.log" 2>&1; then
  cat "$work/geometry.log"; exit 1
fi
cat "$work/geometry.log"
if grep -E -i '(ERROR:|Parse Error:|Invalid access to property|FATAL:)' "$work/geometry.log"; then
  exit 1
fi

echo "== Godot: movimento, inquadratura e resistenza capanna =="
if ! "$GODOT" --headless --path . --script tests/movement_camera_and_resistance.gd >"$work/camera.log" 2>&1; then
  cat "$work/camera.log"; exit 1
fi
cat "$work/camera.log"
if grep -E -i '(ERROR:|Parse Error:|Invalid access to property|FATAL:)' "$work/camera.log"; then
  exit 1
fi
