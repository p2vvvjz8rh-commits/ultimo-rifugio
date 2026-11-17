"""Converte il pacchetto CI gia verificato in distribuzione portatile stabile."""
from pathlib import Path
import hashlib
import shutil

folder = Path('build/alfa14')
assert (folder/'CANDIDATA_PORTATILE.txt').is_file()
for line in (folder/'SHA256SUMS.txt').read_text().splitlines():
    digest, name = line.split(maxsplit=1)
    assert hashlib.sha256((folder/name).read_bytes()).hexdigest() == digest
(folder/'CANDIDATA_PORTATILE.txt').rename(folder/'PORTATILE.txt')
(folder/'PORTATILE.txt').write_text('Alfa 14 portatile: conservare questo file per usare salvataggi/ accanto al gioco.\n', encoding='utf-8')
(folder/'AVVIA_CANDIDATA.bat').rename(folder/'AVVIA_ALFA14.bat')
(folder/'LEGGIMI.txt').write_text(
    'ULTIMO RIFUGIO - ALFA 14\n\n'
    'Estrai tutti i file in una cartella e apri AVVIA_ALFA14.bat.\n'
    'Questa distribuzione portatile salva in salvataggi/ accanto al gioco.\n'
    'Conserva PORTATILE.txt e una copia delle partite precedenti.\n'
    'La prima apertura di una partita precedente conserva partita_pre_alfa14.json.\n\n'
    'WASD: movimento rispetto alla camera. Clic sinistro: muovi.\n'
    'Clic destro: ispeziona/ripara. E: banco. B: costruisci/ripara.\n'
    'F: recupero materiali. R: radio. ESC: pausa.\n'
    'Rotella: zoom. Rotella premuta e trascinamento: orbita a 360 gradi.\n'
    'Trascinamento verticale: inclinazione. Home: visuale iniziale.\n'
    'N: nuova partita con backup. F3: controlli di prova.\n\n'
    'Versione Godot: 4.7.2. Formato partita: JSON v8.\n', encoding='utf-8')
shutil.copyfile('VERSIONE.txt', folder/'VERSIONE.txt')
shutil.copyfile('docs/LICENSE_QUATERNIUS.txt', folder/'LICENSE_QUATERNIUS.txt')
print('Pacchetto stabile Alfa 14 preparato senza includere salvataggi locali.')
