extends SceneTree
var failures := 0
func check(condition: bool, description: String) -> void:
    if not condition:
        failures += 1
        push_error(description)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var directory: String = ProjectSettings.globalize_path("user://cycle15-test")
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",directory)
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.set_process(false)
    game.hero.set_physics_process(false)
    game.expedition.set_physics_process(false)
    game.salvage.set_process(false)
    game.skip_save_on_exit = true
    for enemy in game.enemies: enemy.queue_free()
    game.enemies.clear()
    var escort = game.expedition
    game.hero.position = escort.START
    check(escort.interact() and not escort.active,"Scorta richiede base costruita")
    game.stockade_built = true
    game._build_stockade()
    game.wood = 200
    game.coins = 100
    game.hero.position = game.repair_bench.position
    game._expand_base()
    check(game.base_level == 1 and game.wood == 200,"Ampliamento bloccato senza progetto")
    game.hero.position = escort.START
    check(escort.interact() and escort.active,"F avvia la scorta vicino al carico")
    game.hero.position += Vector3(-2.5,0,0)
    await physics_frame
    var start: Vector3 = escort.cart.position
    escort._advance(.1)
    check(escort.cart.position.x < start.x,"Carretto segue fisicamente il protagonista vicino")
    game.hero.position += Vector3(-8,0,0)
    var waiting: Vector3 = escort.cart.position
    escort._advance(.1)
    check(Vector2(escort.cart.position.x,escort.cart.position.z).distance_to(Vector2(waiting.x,waiting.z)) < .001,"Carico aspetta se il protagonista si allontana")
    game.paused = true
    escort.damage(100)
    escort._advance(1)
    check(escort.hp == escort.MAX_HP,"Pausa sospende danni e avanzamento")
    game.paused = false
    game.hero.position = Vector3(-15,0,-15)
    game._spawn_enemy(escort.cart.position+Vector3(1,0,0),"normal",false)
    var enemy = game.enemies.back()
    enemy.set_physics_process(false)
    enemy._physics_process(.1)
    check(escort.hp < escort.MAX_HP,"Zombie vagante puo attaccare il carico senza nuovi tipi")
    enemy.queue_free()
    game.enemies.clear()
    escort.travelled = 4.1
    escort._advance(.1)
    check(escort.ambushes == 1 and game.enemies.size() == 2,"Primo incontro attivato una volta")
    var mission: Dictionary = escort.save_data()
    escort.load_data(mission)
    escort._advance(.1)
    check(escort.ambushes == 1 and game.enemies.size() == 2,"Ricaricare non duplica lo stesso incontro")
    escort.hp = 67
    game._save_progress()
    escort.active = false
    escort.hp = escort.MAX_HP
    game._load_progress()
    check(escort.active and escort.hp == 67 and escort.ambushes == 1,"Partita completa ripristina carico danneggiato e soglia incontri")
    escort.damage(200)
    check(not escort.active and not escort.blueprint and game.wood == 200,"Fallimento senza premi ne perdita risorse precedenti")
    check(escort.ready_at == game.elapsed+60,"Recupero ripetibile dopo fallimento")
    game.elapsed = escort.ready_at
    game.hero.position = escort.START
    escort.interact()
    escort.cart.position = Vector3(0,.12,game.gate_front_z()+2)
    escort._advance(.1)
    check(not escort.active and escort.blueprint and escort.completions == 1,"Consegna al cancello sblocca progetto")
    check(game.wood == 235 and game.coins == 125,"Premio unico 35 legno e 25 monete")
    escort._deliver()
    check(game.wood == 235 and escort.completions == 1,"Nessun premio duplicato chiamando di nuovo consegna")
    game.wall_segments[0]["hp"] = 0.0
    game.wall_segments[1]["hp"] = 72.0
    game.gate_hp = 61
    game.base_hp = 121
    game.bench_hp = 92
    game.hero.position = game.repair_bench.position
    game._expand_base()
    check(game.base_level == 2 and game.wood == 115 and game.coins == 65,"Ampliamento applica costo esatto una sola volta")
    check(game.wall_segments.size() == 9 and game.wall_segments[0]["hp"] == 0 and game.wall_segments[1]["hp"] == 72,"Espansione conserva sezioni e danni, compresa breccia")
    check(game.gate_hp == 61 and game.base_hp == 121 and game.bench_hp == 92,"Espansione non ripara gratuitamente le strutture")
    check(game.gate_left.position.z == 6.5 and game.wall_segments[0]["position"].z == -10,"Nuovo perimetro e cancello coerenti")
    game._expand_base()
    check(game.wood == 115,"Nessun secondo acquisto dopo espansione")
    game.hero.position = Vector3(0,0,6)
    game._update_gate(1)
    await physics_frame
    await physics_frame
    check(game.gate_left_collision.disabled and not game.gate_barrier.disabled,"Cancello ampliato conserva passaggio riservato al protagonista")
    check(game.wall_segments[0]["collider"].disabled,"Breccia conserva collider disabilitato dopo ricostruzione")
    check(game.defense_target(Vector3(0,0,8)).is_equal_approx(Vector3(0,0,7.55)),"Zombie puntano il nuovo cancello")
    game.attack_defense_at(Vector3(0,0,7.55),10)
    check(is_equal_approx(game.gate_hp,57.4),"Attacco al nuovo cancello danneggia la struttura corretta")
    game._save_progress()
    var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game._save_directory().path_join("partita.json")))
    check(saved.version == 8 and saved.base_level == 2 and saved.expedition.blueprint,"Nuovi campi opzionali senza cambiare formato JSON")
    game.base_level = 1
    escort.blueprint = false
    game._load_progress()
    check(game.base_level == 2 and escort.blueprint and game.gate_left.position.z == 6.5,"Espansione e progetto sopravvivono al caricamento")
    game.hero.position = game.repair_bench.position
    game.wood = 100
    game._repair_all_at_bench()
    check(game.gate_hp == game.GATE_HP_MAX and game.wall_segments[0]["hp"] == game.WALL_HP_MAX,"Ripara tutto funziona nel cortile ampliato")
    game.queue_free()
    await process_frame
    # Un salvataggio autentico del formato precedente non contiene campi Alfa 15.
    var legacy := {"version":8,"game_release":"alfa14","wood":398,"coins":437,"hp":94,"px":0,"pz":7,"stockade_built":true,"gate_hp":91,"wall_hp":[19,21],"defense_hp_scale":240}
    var path: String = directory.path_join("salvataggi/partita.json")
    var raw := JSON.stringify(legacy)
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(raw)
    file.close()
    var old_game = load("res://scripts/world.gd").new()
    root.add_child(old_game)
    old_game.set_process(false)
    old_game.hero.set_physics_process(false)
    old_game.expedition.set_physics_process(false)
    old_game.salvage.set_process(false)
    old_game.skip_save_on_exit = true
    check(old_game.base_level == 1 and not old_game.expedition.active and not old_game.expedition.blueprint,"Partite Alfa 14 caricate con base originale e attivita da iniziare")
    check(old_game.wood == 398 and old_game.coins == 437 and old_game.gate_hp == 91 and old_game.wall_segments[0]["hp"] == 19,"Progresso e danni precedenti conservati")
    check(FileAccess.get_file_as_string(directory.path_join("salvataggi/partita_pre_alfa15.json")) == raw,"Backup pre Alfa 15 identico all'originale")
    old_game._save_progress()
    var count: int = DirAccess.get_files_at(directory.path_join("salvataggi")).size()
    old_game._load_progress()
    check(DirAccess.get_files_at(directory.path_join("salvataggi")).size() == count,"Nessuna duplicazione backup su riapertura Alfa 15")
    old_game.queue_free()
    await process_frame
    var protected_dir: String = directory.path_join("backup-failure")
    var protected_path: String = protected_dir.path_join("salvataggi/partita.json")
    DirAccess.make_dir_recursive_absolute(protected_dir.path_join("salvataggi/partita_pre_alfa15.json"))
    file = FileAccess.open(protected_path,FileAccess.WRITE)
    file.store_string(raw)
    file.close()
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",protected_dir)
    var protected_game = load("res://scripts/world.gd").new()
    root.add_child(protected_game)
    protected_game.process_mode = Node.PROCESS_MODE_DISABLED
    protected_game.skip_save_on_exit = true
    check(not protected_game.save_backup_ready,"Backup pre Alfa 15 fallito blocca le scritture")
    protected_game.wood = 999
    protected_game._save_progress()
    check(FileAccess.get_file_as_string(protected_path) == raw,"Partita Alfa 14 intatta se il nuovo backup fallisce")
    protected_game.queue_free()
    await process_frame
    print("Scorta, ampliamento e compatibilita Alfa 15: %d errori" % failures)
    quit(1 if failures else 0)
