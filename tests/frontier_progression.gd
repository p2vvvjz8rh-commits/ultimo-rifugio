extends SceneTree
var failures := 0
func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error(reason)
func _initialize() -> void: call_deferred("run")
func complete_route(game, heavy: bool = true) -> void:
    var f = game.frontier
    var area: int = f.active_area
    if area == 2:
        for enemy in game.enemies:
            if is_instance_valid(enemy) and enemy.position.x > 40: enemy.position = f.center(area)+Vector3(13,0,-12)
    game.hero.position = f.point(area,2)
    f.interact()
    check(not f.primary,"Recupero principale richiede entrambi i dispositivi")
    for i in range(2):
        game.hero.position = f.point(area,i)
        f.interact()
        if area == 1 and i == 0: f.set_power_mode(false)
        if area == 2:
            for enemy in game.enemies:
                if is_instance_valid(enemy) and enemy.position.x > 40: enemy.queue_free()
    game.hero.position = f.point(area,3)
    f.take_loot(3,heavy)
    game.hero.position = f.point(area,2)
    f.take_loot(2,false)
    check(f.note_open and game.paused,"Lettura immediata anche quando l appunto era gia nello storico")
    f.close_note()
    check(f.primary,"Recupero principale sbloccato dalle azioni sul campo")
func run() -> void:
    var directory: String = ProjectSettings.globalize_path("user://frontier-tests")
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",directory)
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.set_process(false)
    game.hero.set_physics_process(false)
    game.expedition.set_physics_process(false)
    game.frontier.set_process(false)
    game.salvage.set_process(false)
    game.skip_save_on_exit = true
    for enemy in game.enemies: enemy.queue_free()
    game.enemies.clear()
    var f = game.frontier
    game.wood = 200
    game.stockade_built = true
    game.hero.position = f.board.position
    f.enter_area(0)
    check(f.active_area == -1,"Spedizioni richiedono ampliamento gia collaudato")
    game.base_level = 2
    game._build_stockade()
    check(not f.unlocked(1) and not f.unlocked(2),"Progressione chiude le attivita successive all'inizio")
    f.enter_area(0)
    check(f.active_area == 0 and game.hero.position.x > 40,"Ingresso in area separata reale")
    check(f.mission_instruction().contains("1/4") and f.objective_index() == 0,"Guida iniziale indica una prima azione concreta")
    f._process(0)
    check(f.objective_marker.visible and f.objective_marker.position == f.point(0,0),"Segnale dorato sul bersaglio reale")
    f.open_menu()
    check(f.menu.visible and f.menu_body.get_child(0).text.contains("COME COMPLETARE"),"G mostra istruzioni complete anche sul campo")
    f.menu.hide()
    for area in range(3):
        var details: Node = f.models[area].get_node("Ambiente_spedizione")
        check(details.find_children("*","MeshInstance3D",true,false).size() > 90,"Allestimento presente in ogni area")
        check(details.find_children("*","StaticBody3D",true,false).is_empty(),"Nuovi dettagli non ostruiscono le interazioni collaudate")
    check(f.clamp_hero(game.hero.position).x > 40,"Movimento non ricondotto alla mappa originale")
    await physics_frame
    await physics_frame
    var detour: Vector3 = f.steer(f.center(0)+Vector3(-7,.13,0),Vector3.RIGHT)
    check(absf(detour.z) > .5,"Zombie aggirano le coperture delle spedizioni senza puntare la base lontana")
    game.hero.position = f.point(0,3)
    f.take_loot(3,true)
    var parts_before: int = f.bag_parts
    f.take_loot(3,true)
    check(f.bag_parts == parts_before,"Nessun bottino duplicato nello stesso sito")
    game.hero.position = f.point(0,4)
    f.take_loot(4,true)
    check(f.bag_parts == parts_before,"Capacita impedisce carico aggiuntivo senza tagliare quello posseduto")
    for i in range(2):
        game.hero.position = f.point(0,i)
        f.interact()
    game.hero.position = f.point(0,2)
    f.take_loot(2,false)
    check(f.note_open and f.note_dialog.visible and game.paused,"Appunto aperto subito alla raccolta con gioco in pausa")
    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    game._input(escape)
    check(game.paused,"Comandi mondo non riattivano il gioco durante la lettura")
    f.note_dialog.confirmed.emit()
    check(not f.note_open and not game.paused,"Chiusura lettore ripristina correttamente il gioco")
    check(f.mission_instruction().contains("4/4") and f.objective_position() == f.entrance(0),"Guida e segnale indicano il rientro dopo il recupero")
    check(f.bag_slots == 3 and f.bag_parts == 5,"Scelta rischio/carico e recupero principale compatibili")
    game._save_progress()
    var raw: String = FileAccess.get_file_as_string(game._save_directory().path_join("partita.json"))
    var active: Dictionary = JSON.parse_string(raw)
    var enemy_count: int = active.frontier.enemies.size()
    check(enemy_count > 0 and enemy_count <= 8,"Incontri della spedizione limitati e salvati")
    game._load_progress()
    await process_frame
    check(f.active_area == 0 and f.bag_parts == 5 and f.primary and game.hero.position.x > 40,"Riapertura completa conserva area e bottino non consegnato")
    check(f.save_data().enemies.size() == enemy_count,"Riapertura non duplica gli incontri e conserva nemici")
    game.hero.position = f.entrance(0)
    f.interact()
    check(f.completed[0] and f.parts == 5 and game.hero.position.x == 0,"Estrazione consegna il carico e conserva il progetto")
    check(game.wood == 235 and f.active_area == -1,"Prima ricognizione premia senza attese e torna al rifugio")
    f.leave_area(true)
    check(f.parts == 5 and game.wood == 235,"Premi non duplicabili dopo il rientro")
    game.hero.position = f.board.position
    f.build_station("workshop")
    check(f.working("workshop") and f.parts == 3 and game.wood == 215,"Officina fisica con costo verificato")
    f.craft_tool()
    check(f.tool and f.parts == 2 and f.unlocked(1),"Strumenti dell'officina aprono nuove attivita")
    f.build_station("storage")
    check(f.working("storage") and f.capacity() == 5 and f.parts == 0,"Magazzino aumenta capacita utile nelle spedizioni")
    f.enter_area(1)
    await complete_route(game)
    game.hero.position = f.point(1,4)
    f.take_loot(4,true)
    check(f.bag_slots == 5 and f.bag_parts == 8 and f.bag_cells == 1,"Seconda area sfrutta magazzino e recupera materiale specifico")
    game.hero.position = f.entrance(1)
    f.interact()
    game.hero.position = f.board.position
    f.build_station("generator")
    check(f.working("generator") and f.cells == 0 and f.parts == 5 and f.unlocked(2),"Generatore consuma la cella recuperata e apre la terza attivita")
    f.craft_kit()
    game.hero.hp = 30
    f.use_kit()
    check(game.hero.hp == 95 and f.kits == 0,"Kit costruito usa risorse e cura solo se necessario")
    game.paused = true
    var wood_before: int = game.wood
    f.craft_kit()
    f.enter_area(2)
    check(f.active_area == -1 and game.wood == wood_before,"Pausa sospende acquisti e partenze")
    game.paused = false
    f.enter_area(2)
    await complete_route(game)
    game.hero.position = f.entrance(2)
    f.interact()
    check(f.completed == [true,true,true],"Percorso completo integrato fra tre aree e costruzioni")
    game.hero.position = f.board.position
    f.stations.storage.hp = 0
    f.sync_stations()
    check(f.capacity() == 3 and f.has_damage(),"Costruzione distrutta perde la funzione")
    var visual = f.stations.storage.visual
    check(visual.rubble.visible,"Nuove postazioni crollano geometricamente a zero HP")
    game.hero.position = f.stations.storage.node.position
    game.manual_target = "station:storage"
    var timber: int = game.wood
    game._repair_selected("station:storage")
    check(f.working("storage") and f.stations.storage.hp == 160 and game.wood == timber-10,"Riparazione individuale nuova postazione completa e proporzionata")
    f.stations.workshop.hp = 45
    f.sync_stations()
    check(f.stations.workshop.visual.heavy_damage.visible,"Deterioramento geometrico delle nuove costruzioni")
    game.wood = 200
    game.hero.position = game.repair_bench.position
    game._repair_all_at_bench()
    check(not game._has_damaged_defenses() and f.stations.workshop.hp == 160,"Ripara tutto include tutte le nuove postazioni")
    game._save_progress()
    var persisted: Dictionary = f.save_data()
    game._load_progress()
    await process_frame
    check(f.completed == [true,true,true] and f.stations.size() == 3 and f.parts == persisted.parts,"Stazioni e progressione completa sopravvivono al caricamento")
    game.hero.position = f.board.position
    f.enter_area(0)
    await complete_route(game,false)
    var safe_parts: int = f.parts
    f.leave_area(false)
    check(f.parts == safe_parts and f.completed == [true,true,true] and f.bag_slots == 0,"Fallimento perde soltanto il carico non consegnato")
    check(f.clamp_hero(Vector3(99,0,99)).is_equal_approx(Vector3(20,0,20)),"Rientro ripristina i limiti originali del movimento")
    game.hero.position = f.board.position
    f.enter_area(1)
    game.hero.position = f.point(1,0)
    f.set_power_mode(true)
    var count_after_choice: int = game.enemies.size()
    f.set_power_mode(true)
    check(f.power_mode == 1 and f.switches[0] and game.enemies.size() == count_after_choice,"Scelta rumorosa applicata una volta e registrata")
    game.hero.position = f.point(1,1)
    f.interact()
    game.hero.position = f.point(1,2)
    f.take_loot(2,false)
    check(f.note_open and game.paused,"Lettura immediata anche quando l appunto era gia nello storico")
    f.close_note()
    check(f.bag_parts == 4,"Argano premia il rischio con due componenti aggiuntivi")
    var banked: int = f.parts
    game.hero.hit_grace = 0
    game.hero.hp = 1
    game.hero.receive_damage(1000)
    check(f.active_area == -1 and f.bag_slots == 0 and f.parts == banked and game.hero.hp == 100,"Morte reale rientra senza perdere progressi gia consegnati")
    check(ResourceLoader.exists("res://resources/field_entries.gd"),"Contenuti di gioco inclusi nel pacchetto")
    f.show_notes()
    check(f.menu_body.get_child_count() >= 4,"Contenuti raccolti consultabili senza errori")
    f.menu.hide()
    # Anche le nuove costruzioni devono essere attaccabili dall'IA, non bloccarla.
    var station_pos: Vector3 = f.stations.workshop.node.position
    var approach: Vector3 = station_pos+Vector3(1.8,0,0)
    check(game.defense_target(approach).distance_to(station_pos) < 1.3,"IA punta la postazione vicina dopo una breccia")
    var hp_before: float = f.stations.workshop.hp
    game.attack_defense_at(approach,10)
    check(f.stations.workshop.hp < hp_before,"Attacco raggiunge gli HP della nuova postazione")
    # L'avvio rapido e' facoltativo e conserva byte per byte la partita esistente.
    game._save_progress()
    var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(game._save_directory().path_join("partita.json"))
    var old_files: PackedStringArray = DirAccess.get_files_at(game._save_directory())
    check(game._prepare_new_game(true),"Demo estesa preparata con backup protettivo")
    var same_backup := false
    for name in DirAccess.get_files_at(game._save_directory()):
        if not old_files.has(name) and name.begins_with("partita_backup_"):
            same_backup = FileAccess.get_file_as_bytes(game._save_directory().path_join(name)) == old_bytes
    check(same_backup,"Avvio rapido conserva esattamente il salvataggio precedente")
    game._load_progress()
    check(game.base_level == 2 and game.weapon_level == 2 and game.wood == 80 and f.completed == [false,false,false],"Avvio rapido salta solo la crescita gia collaudata, senza completare il contenuto nuovo")
    # Dati precedenti: nessun nuovo campo richiesto e nessuna modifica al carretto.
    f.load_data({})
    check(f.parts == 0 and f.active_area == -1 and f.stations.is_empty() and not f.tool,"Valori opzionali sicuri per salvataggi precedenti")
    game.queue_free()
    await process_frame
    print("Spedizioni e postazioni: %d errori" % failures)
    quit(1 if failures else 0)
