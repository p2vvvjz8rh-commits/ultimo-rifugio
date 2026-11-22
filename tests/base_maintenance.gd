extends SceneTree

var failures: int = 0

func check(condition: bool, description: String) -> void:
    if not condition:
        failures += 1
        push_error(description)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.set_process(false)
    game.hero.set_physics_process(false)
    for enemy in game.enemies:
        enemy.queue_free()
    game.enemies.clear()
    game.wood = 100
    game.stockade_built = true
    game._build_stockade()
    game.hero.position = Vector3(0,0,4)
    game._update_gate(1.0)
    await physics_frame
    await physics_frame
    check(game.gate_left_collision.disabled, "Ante aperte per il protagonista")
    check(not game.gate_barrier.disabled, "Blocco zombie attivo con ante aperte")
    check(not game.has_clear_path(Vector3(0,0,5),Vector3(0,0,3)), "Zombie non vedono un passaggio attraverso il cancello")
    var actor := CharacterBody3D.new()
    actor.collision_mask = 5
    actor.collision_layer = 0
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = .38
    capsule.height = 1.5
    collider.shape = capsule
    collider.position.y = .75
    actor.add_child(collider)
    game.add_child(actor)
    actor.position = Vector3(0,.1,5.2)
    await physics_frame
    check(actor.test_move(actor.global_transform,Vector3(0,0,-2)), "Collisione fisica zombie al cancello")
    actor.collision_mask = 1
    check(not actor.test_move(actor.global_transform,Vector3(0,0,-2)), "Protagonista attraversa le ante aperte")
    game.hero.position = Vector3(0,0,3)
    game._spawn_enemy(Vector3(0,0,5.05),"normal",false)
    var zombie = game.enemies.back()
    zombie.set_physics_process(false)
    zombie._physics_process(.1)
    check(game.gate_hp < game.GATE_HP_MAX, "Zombie attirato attacca il cancello invece di attraversarlo")
    zombie.queue_free()
    game.enemies.clear()
    game.gate_hp = 0
    game.gate_broken = true
    game._sync_gate_collision(true)
    await physics_frame
    await physics_frame
    actor.collision_mask = 5
    check(not actor.test_move(actor.global_transform,Vector3(0,0,-2)), "Cancello distrutto attraversabile")
    game.hero.position = game.repair_bench.position
    game.bench_hp = 30
    game.manual_target = "bench"
    game._repair_selected("bench")
    check(game.bench_hp == 130 and game.wood == 93, "Costo proporzionale banco e riparazione completa")
    game.camera.position = game.repair_bench.global_position + Vector3(0,10,.01)
    game.camera.look_at(game.repair_bench.global_position)
    var screen: Vector2 = game.camera.unproject_position(game.repair_bench.global_position+Vector3.UP)
    game._inspect_structure(screen)
    check(game.manual_target == "bench", "Selezione banco tramite raggio del mouse")
    game.repair_popup.hide()
    game.wall_segments[0]["hp"] = 0.0
    game.wall_segments[1]["hp"] = 80.0
    game.hero.position = game.wall_segments[0]["position"]
    game.manual_target = "wall:0"
    game._repair_selected("wall:0")
    check(game.wall_segments[0]["hp"] == 240 and game.wall_segments[1]["hp"] == 80, "Riparazione della sola sezione selezionata")
    game.wood = 0
    game._repair_selected("wall:0")
    check(game.wall_segments[0]["hp"] == 240, "Nessuna riparazione senza risorse")
    game.wood = 100
    game.hero.position = Vector3(20,0,20)
    game._repair_selected("wall:0")
    check(game.wood == 100, "Distanza ricontrollata alla conferma")
    game.base_hp = 20
    game.hero.position = game.repair_bench.position
    game._repair_all_at_bench()
    check(game.wood == 67 and not game._has_damaged_defenses(), "Ripara tutto completo e costo unico")
    game._repair_all_at_bench()
    check(game.wood == 67, "Nessun costo per strutture integre")
    await physics_frame
    await physics_frame
    check(not game.gate_barrier.disabled and not game.wall_segments[0]["collider"].disabled, "Collisioni ripristinate dopo riparazione")
    game.wall_segments[0]["hp"] = 73.0
    game.gate_hp = 81
    game.wood = 37
    game._save_progress()
    var saved = JSON.parse_string(FileAccess.get_file_as_string(game._save_directory().path_join("partita.json")))
    check(saved["version"] == 8, "Formato salvataggio invariato")
    game._load_progress()
    check(game.wood == 37 and game.gate_hp == 81 and game.wall_segments[0]["hp"] == 73, "Salvataggio e ricaricamento con danni indipendenti")
    # Fixture del vecchio formato v8: campi opzionali assenti e scala originaria.
    var legacy := {"version":8,"wood":29,"coins":17,"stockade_built":true,"gate_hp":55,"wall_hp":[120],"px":2,"pz":8,"hp":72}
    var file := FileAccess.open(game._save_directory().path_join("partita.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy))
    file.close()
    game._load_progress()
    check(game.wood == 29 and game.coins == 17 and game.hero.hp == 72, "Progresso legacy conservato")
    check(game.gate_hp == 140 and game.bench_hp == 130, "Scala legacy e campi opzionali")
    game.skip_save_on_exit = true
    game.queue_free()
    await process_frame
    print("Manutenzione base: %d errori" % failures)
    quit(1 if failures else 0)
