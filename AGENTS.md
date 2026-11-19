# Ultimo Rifugio — istruzioni permanenti per agenti

## Scopo
Progetto Godot 4.x per Windows con aggiornamento automatico via GitHub. Lo sviluppo deve essere graduale, affidabile e divertente. Il giocatore è anche il tester principale e vuole scoprire la trama **senza spoiler**. Questo file è pubblico e volutamente non contiene eventi narrativi.

## Sorgenti affidabili del progetto
- `project.godot`, `scenes/World.tscn` e `scripts/*.gd`.
- `ROADMAP_FUTURO.txt`: backlog di gameplay; distinguere idee da funzionalità realizzate.
- `QUADERNO_NARRATIVO.txt`: **solo vincoli narrativi generali e accordi di riservatezza**; non anticipare sviluppi della storia.
- `aggiornamenti/AGGIORNA_E_GIOCA.ps1`: aggiornatore del PC Windows.
- `tools/CREA_WINDOWS.ps1`: build portatile Windows con versione Godot specificata nello script; controllare eventuale differenza dal motore cloud.

## Regola fondamentale di pubblicazione
**Non committare modifiche sperimentali su `main`.** Il launcher dell'utente scarica automaticamente l'ultimo commit di `main`: perfino un commit di sola configurazione può provocare una nuova compilazione sul suo PC.

1. Lavora su un ramo dedicato, ad esempio `sviluppo-agenti` o `feature/<tema>`.
2. Prima di proporre il merge, esegui almeno import e avvio headless Godot; controlla errori di parser, script e asset, quindi i test pertinenti.
3. Se l'ambiente non dispone di Godot, dichiara esplicitamente che i test non sono stati eseguiti; non inventare successi.
4. Apri una pull request (preferibilmente bozza finché non completata), documentando solo le **funzionalità non narrative** e rischi residui.
5. Non effettuare merge in `main` finché la compilazione e la compatibilità dei salvataggi non sono verificate. Se è indispensabile un collaudo manuale, chiedi al tester.
6. Pubblica versioni consistenti, non singoli commit intermedi.

## Salvataggi e ripristino
- Formato corrente: JSON `version: 8` con retrocompatibilità tramite valori opzionali. Non perdere il progresso delle partite esistenti.
- Il salvataggio usa `_save_progress()` in `scripts/world.gd`; controlla `is_instance_valid(hero)` prima di accedere a trasformazioni e punti vita, anche alla chiusura.
- Non sovrascrivere né cancellare file `salvataggi/partita.json`; per nuova partita si conserva backup.
- Non migrare versione dati senza test di caricamento dei salvataggi più vecchi.
- `config/name` conserva il nome storico di Alfa 13 per mantenere il percorso user://. Non rinominarlo per cambiare il titolo della release. `PORTATILE.txt` identifica i pacchetti stabili con dati accanto all'EXE; `CANDIDATA_PORTATILE.txt` separa i collaudi.
- Il builder usa `ULTIMO_RIFUGIO_TEST_DATA` per isolare i controlli editor. La prima apertura di un salvataggio precedente crea un backup pre Alfa 14; il ciclo Alfa 15 conserva anche una copia pre Alfa 15; in caso di errore non scrivere sopra la partita originale.
- Cache `.godot/`, eseguibili, file temporanei, log e salvataggi locali non devono entrare nei commit.

## Regole di gameplay già stabilite
- Controlli: movimento WASD/mouse, E banco, B costruzione/riparazione, T avvio orda test, F3 pannello test, N nuova partita, R radio. Rotella premuta e trascinamento: orbita a 360 gradi; Home ripristina la visuale. WASD segue la camera ruotata, rotella libera mantiene lo zoom.
- Non aggiungere adesso sistemi pesanti di fame/sete, gestione complessa della squadra o nuovi tipi di zombie senza motivazione e test.
- Difese aggiuntive (trappole, percorsi, buche): **rinviate** finché la base non sarà sufficientemente ampia.
- Tutte le costruzioni hanno salute autonoma, barre sotto il 100%, tre condizioni geometriche (integro, danneggiato, grave) e crollo riconoscibile a zero.
- Per ogni costruzione futura associare tutte le mesh al componente `structure_visual.gd`: spaccature e parti mancanti devono sostituire la geometria sana. Per modelli importati predisporre varianti appropriate; colore, decal o piccoli detriti aggiunti da soli non bastano. Verificare riparazione reversibile e collisioni invariate.
- Alfa 14 approvata dal tester anche dopo installazione tramite aggiornatore Windows. Alfa 15 resta sul ramo separato fino al nuovo collaudo.
- In sviluppo Alfa 15: carretto e ampliamento gia provati; ciclo esteso in docs/DEMO_ESTESA.txt. Tre spedizioni e postazioni integrate, nessun merge automatico.
- Riparazioni individuali sempre complete; costo proporzionale agli HP mancanti. Ripara tutto somma gli stessi preventivi e non esegue lavori parziali.
- Ogni generazione zombie deve usare safe_enemy_spawn; mai generare dentro il perimetro attuale. I giunti fisici delle pareti si sovrappongono per evitare attraversamenti sul bordo condiviso.
- G apre la bacheca; H usa kit. Conservare stato della spedizione, carico e incontri nei salvataggi v8. Nessun nuovo tipo di zombie, difese avanzate ancora rinviate.
- Implementato in Alfa 14: cancello riservato al protagonista, ripara tutto al banco, ispezione/riparazione individuale, deterioramento geometrico, recupero materiali e camera orbitale.
- Conserva la possibilità di raggiungere e usare il banco, l'accesso alla base e il salvataggio durante aggiornamenti.
- Nuove missioni e aree devono avere un obiettivo comprensibile ed evitare ripetizione eccessiva. Guida per fasi persistente, segnale sul bersaglio e istruzioni G disponibili anche sul campo.
- Allestimenti delle missioni: nessuna collisione decorativa nuova; conservare i corpi fisici collaudati. I terreni visivi hanno ground_surface=true e sono esclusi dalla trasparenza degli ostacoli. Atmosfera e luce locali devono ripristinare la base al rientro. Vegetazione in MultiMesh e dettagli statici accorpati; test mission_art oltre ai test di progressione.
- Operazioni: briefing con scopo e beneficio; cerchio sul bersaglio, non sentiero. Conservare il percorso degli incarichi gia attivi privi di mission_ops. Nuove operazioni devono essere completate prima di confermare il risultato e rientrare; note e casse sono secondarie.
- Le note raccolte vanno aperte immediatamente con pausa protettiva; ripristinare lo stato precedente alla chiusura. Non rivelare testi narrativi nei controlli grafici: usare testo di prova.

## Narrazione: protocollo anti-spoiler
- La regola condivisa è: **«La storia sarà il mio segreto e la tua avventura»**.
- Non esporre nei messaggi, nei changelog, nei titoli di commit, nei titoli delle PR, nei riepiloghi dei test o nel testo delle risposte identità, colpi di scena, dialoghi, segreti e futuro della storia.
- Descrivere gli update narrativi solo genericamente (ad es. "contenuti narrativi aggiuntivi").
- Non scrivere nel repository pubblico una "sceneggiatura completa" o documenti che anticipano il finale. I sorgenti pubblici rimangono ispezionabili: i nomi neutri riducono gli spoiler accidentali ma **non forniscono segretezza tecnica**. Quando servirà, discutere un archivio narrativo separato con accessi dedicati.
- Il giocatore può rivedere **solo gli eventi già vissuti** e dare feedback senza apprendere le conseguenze future.
- Scene illustrative o fumetti, dialoghi e pensieri sono possibili strumenti di storytelling, da usare con moderazione.
- Nessun cambiamento narrativo deve cancellare la partita o imporre uno stato irreversibile senza possibilità di recupero.

## Validazione tecnica minima
- Con Godot disponibile: import headless (`godot --headless --path . --editor --import`) e avvio breve (`godot --headless --path . --quit-after 5`).
- Usare Godot 4.7.2 sia per i controlli Linux sia per il builder Windows; non considerare automaticamente equivalenti altre versioni.
- Non dichiarare verificato il rendering interattivo o l'esportazione Windows con un test headless Linux.
- Eseguire test in una cartella dati isolata per non toccare salvataggi reali; se non possibile, usare solo una sessione effimera.
- Un test che passa non autorizza da solo la pubblicazione automatica; proteggere prima la versione giocabile.

## Metodo di consegna
- Il tester viene coinvolto per verificare sensazioni, estetica e comportamento reale, non per modificare manualmente file.
- Pubblicare una sola versione testabile quando un insieme coerente di funzionalità è pronto.
- Riportare risultati dei test realmente eseguiti, blocchi e limitazioni in maniera trasparente.
