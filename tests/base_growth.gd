extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void: call_deferred("run")
func quiet(game) -> void:
    for enemy in game.enemies:
        if is_instance_valid(enemy):
            enemy.defeated = true
            enemy.queue_free()
    game.enemies.clear()
func run() -> void:
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",ProjectSettings.globalize_path("user://growth-tests"))
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.set_process(false)
    game.hero.set_physics_process(false)
    game.salvage.set_process(false)
    game.expedition.set_physics_process(false)
    game.frontier.set_process(false)
    game.frontier.ops.set_process(false)
    game.skip_save_on_exit = true
    quiet(game)
    game.stockade_built = true
    game.base_level = 2
    game._build_stockade()
    var f = game.frontier
    var g = f.growth
    game.wood = 200
    f.parts = 30
    f.cells = 0
    f.tool = true
    f.completed = [false,false,false]
    f.ops.results = [true,true,true]
    game.hero.position = f.board.position
    check(not g.upgrade("unknown"),"Chiavi sconosciute rifiutate senza spese")
    check(not g.upgrade("workshop"),"Nessun potenziamento su edificio assente")
    for key in ["workshop","storage","generator"]: f._create_station(key,91)
    check(not g.upgrade("workshop") and game.wood == 200,"Progresso richiesto senza consumo prematuro")
    f.completed = [true,true,true]
    game.wood = 0
    check(not g.upgrade("workshop") and f.parts == 30 and g.level("workshop") == 1,"Materiali insufficienti: nessun pagamento parziale")
    game.wood = 200
    game.paused = true
    check(not g.upgrade("workshop"),"Pausa impedisce acquisti")
    game.paused = false
    game.hero.position = Vector3(14,0,14)
    check(not g.upgrade("workshop"),"Potenziamento disponibile soltanto alla bacheca")
    game.hero.position = f.board.position
    for key in ["workshop","storage","generator"]:
        var before_wood: int = game.wood
        var before_parts: int = f.parts
        var count: int = f.stations[key].visual.bound_meshes.size()
        check(g.upgrade(key),"Potenziamento installabile con requisiti sufficienti")
        check(g.level(key) == 2 and f.stations[key].hp == 91,"Livello cresce senza riparazioni gratuite")
        check(game.wood == before_wood-int(g.UPGRADES[key].wood) and f.parts == before_parts-int(g.UPGRADES[key].parts),"Pagamento esatto una volta sola")
        check(f.stations[key].visual.bound_meshes.size() > count,"Crescita geometrica associata al deterioramento")
        check(not g.upgrade(key),"Acquisto ripetuto non duplica livelli o ricompense")
    await process_frame
    quiet(game)
    check(f.capacity() == 7 and g.kit_capacity() == 5 and g.kit_healing() == 85,"Benefici concreti di trasporto e preparazione")
    check(is_equal_approx(g.repair_factor(),.65) and g.warning_seconds() == 60,"Generatore integra manutenzione e rete esistenti")
    var light = f.stations.generator.node.get_node("Luce_potenziamento")
    check(light.visible,"Illuminazione operativa al livello avanzato")
    for key in f.stations:
        f.stations[key].hp = 0
    f.sync_stations()
    check(f.capacity() == 3 and g.kit_capacity() == 3 and g.repair_factor() == 1 and g.warning_seconds() == 20 and not light.visible,"Edifici distrutti sospendono benefici e luci")
    for key in f.stations:
        check(f.stations[key].visual.rubble.visible,"Anche il potenziamento crolla a zero HP")
    f.restore_all()
    check(f.capacity() == 7 and light.visible and g.level("workshop") == 2,"Riparazione ripristina benefici senza riacquisto")
    game.wall_segments[0].hp = 120
    check(game.repair_cost("wall:0") == 4,"Sconto applicato al preventivo proporzionale reale")
    check(game.repair_all_cost() == game.repair_cost("wall:0"),"Ripara tutto mantiene lo stesso preventivo individuale scontato")
    game.wall_segments[0].hp = 240
    game.hero.position = f.board.position
    check(g.set_salvage_mode(true),"Preparazione tecnica con officina funzionante e attrezzi")
    var salvage = game.salvage
    game.hero.position = salvage.SITES[0]
    salvage.interact()
    check(salvage.searching == 0 and salvage.searching_technical,"Raccolta normale conserva interazione e usa preparazione scelta")
    salvage._complete_search()
    quiet(game)
    check(salvage.carried == 1 and salvage.technical_cargo == 1,"Il componente rimane nel carico e non nel magazzino")
    game.hero.position = f.board.position
    check(not g.set_salvage_mode(false),"Impossibile cambiare destinazione del carico gia raccolto")
    var wood: int = game.wood
    var parts: int = f.parts
    var coins: int = game.coins
    game._save_progress()
    salvage.technical_cargo = 0
    g.levels.clear()
    f.kits = 0
    game._load_progress()
    await process_frame
    quiet(game)
    check(g.level("storage") == 2 and salvage.technical_cargo == 1 and g.technical_salvage,"Salvataggio v8 conserva potenziamenti, scelta e carico tecnico")
    game.hero.position = Vector3(0,.13,0)
    salvage.deposit()
    check(game.wood == wood+6 and f.parts == parts+1 and game.coins == coins,"Consegna tecnica scambia monete e legno per componenti")
    salvage.deposit()
    check(f.parts == parts+1,"Consegna ripetuta non duplica componenti")
    game.hero.position = f.board.position
    g.set_salvage_mode(false)
    salvage.ready_at[0] = 0
    game.hero.position = salvage.SITES[0]
    salvage.interact()
    salvage._complete_search()
    quiet(game)
    wood = game.wood
    coins = game.coins
    game.hero.position = Vector3(0,.13,0)
    salvage.deposit()
    check(game.wood == wood+12 and game.coins == coins+8,"Recupero di legname conserva ricompense approvate")
    salvage.technical_cargo = 1
    salvage.carried = 1
    salvage.drop_carried()
    check(salvage.technical_cargo == 0 and salvage.carried == 0,"Perdita del carico include i componenti non consegnati")
    f.kits = 4
    game.hero.hp = 10
    f.use_kit()
    check(game.hero.hp == 95 and f.kits == 3,"Kit potenziato cura senza superare gli HP massimi")
    f.kits = 5
    f.bag_slots = 7
    var state: Dictionary = f.save_data()
    f.load_data(state)
    await process_frame
    check(f.kits == 5 and f.bag_slots == 7 and f.capacity() == 7,"Riapertura non tronca scorte e carichi potenziati")
    state.erase("base_growth")
    f.load_data(state)
    await process_frame
    check(g.level("storage") == 1 and not g.technical_salvage and f.capacity() == 5,"Vecchio salvataggio conserva edifici e comportamento di livello iniziale")
    salvage.load_data({"carried":2,"deliveries":4,"ready_at":[0,0,0]})
    check(salvage.carried == 2 and salvage.technical_cargo == 0,"Carico legacy resta legname")
    game._save_progress()
    var save_path: String = game._save_directory().path_join("partita.json")
    var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
    legacy.frontier.erase("base_growth")
    legacy.salvage.erase("technical_cargo")
    var before := JSON.stringify(legacy)
    var stream := FileAccess.open(save_path,FileAccess.WRITE)
    stream.store_string(before)
    stream.close()
    game._load_progress()
    await process_frame
    var exact_backup := false
    for file_name in DirAccess.get_files_at(game._save_directory()):
        if file_name.begins_with("partita_pre_crescita"):
            if FileAccess.get_file_as_string(game._save_directory().path_join(file_name)) == before: exact_backup = true
    check(exact_backup and game.save_backup_ready,"Prima apertura legacy conserva una copia identica pre crescita")
    game.queue_free()
    await process_frame
    print("Crescita rifugio e preparazione recuperi: %d errori" % failures)
    quit(1 if failures else 0)
