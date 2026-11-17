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
    game.salvage.set_process(false)
    game.radio_station.set_process(false)
    for enemy in game.enemies:
        enemy.queue_free()
    game.enemies.clear()
    game.stockade_built = true
    game._build_stockade()
    var component = game.wall_segments[0]["durability"]
    var plank: MeshInstance3D = component.bound_meshes[0]["mesh"]
    var original: Transform3D = plank.transform
    component.set_health(200)
    check(component.damage_stage == 1 and component.bar.visible, "Danno lieve leggibile")
    component.set_health(80)
    check(component.damage_stage == 2 and component.heavy_damage.visible, "Danno grave con schegge a terra")
    var damaged: Transform3D = plank.transform
    for index in range(60):
        component.set_health(80)
    check(plank.transform.is_equal_approx(damaged), "Nessuna deriva delle deformazioni")
    component.set_health(0)
    check(not plank.visible and component.rubble.visible, "Crollo separato dalla struttura")
    component.set_health(240)
    check(plank.visible and plank.transform.is_equal_approx(original) and not component.bar.visible, "Riparazione ripristina esattamente la geometria")
    var activity = game.salvage
    activity.load_data({})
    game.elapsed = 10
    game.wood = 30
    game.coins = 20
    game.hero.since_last_hit = 100
    game.hero.position = Vector3.ZERO
    activity.interact()
    check(activity.searching == -1, "Recupero richiede vicinanza")
    game.hero.position = activity.SITES[0]
    activity.interact()
    activity._process(1)
    game.hero.position.x += 1
    activity._process(.1)
    check(activity.searching == -1 and activity.carried == 0, "Movimento interrompe il recupero")
    game.hero.position = activity.SITES[0]
    activity.interact()
    game.hero.since_last_hit = 0
    activity._process(.1)
    check(activity.searching == -1, "Un colpo interrompe il recupero")
    game.hero.since_last_hit = 100
    for index in range(3):
        game.hero.position = activity.SITES[index]
        activity.interact()
        game.paused = true
        activity._process(8)
        check(activity.progress == 0, "La pausa ferma il recupero")
        game.paused = false
        activity._process(4.1)
        check(activity.carried == index+1, "Carico aumenta una volta per punto")
        check(game.wood == 30 and game.coins == 20, "Ricompensa solo alla consegna")
        activity.interact()
        check(activity.searching == -1, "Cooldown evita duplicazione del carico")
    activity.deposit()
    check(activity.carried == 3, "Nessuna consegna fuori base")
    game._save_progress()
    activity.drop_carried()
    game._load_progress()
    check(activity.carried == 3 and activity.ready_at[0] == 250, "Carico e cooldown persistono dopo ricaricamento")
    game.hero.position = Vector3(0,.13,1)
    activity._process(.1)
    check(activity.carried == 0 and game.wood == 66 and game.coins == 54 and activity.deliveries == 1, "Consegna completa e bonus rischio")
    activity._process(.1)
    check(game.wood == 66 and game.coins == 54, "Consegna non duplicabile")
    activity.carried = 2
    game.hero.hp = 1
    game.hero.hit_grace = 0
    game.hero.receive_damage(100)
    check(activity.carried == 0 and game.hero.hp == 100, "Sconfitta lascia il carico senza bloccare il rientro")
    activity.load_data({"carried":99,"ready_at":[-4],"deliveries":-2})
    check(activity.carried == 3 and activity.ready_at == [0.0,0.0,0.0] and activity.deliveries == 0, "Campi opzionali limitati e array incompleti")
    activity.load_data({})
    check(activity.carried == 0, "Salvataggi v8 senza nuova attivita' caricabili")
    game.skip_save_on_exit = true
    game.queue_free()
    await process_frame
    print("Esplorazione e deterioramento: %d errori" % failures)
    quit(1 if failures else 0)
