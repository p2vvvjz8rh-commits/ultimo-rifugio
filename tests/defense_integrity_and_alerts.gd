extends SceneTree
var failures := 0
var probes := 0
func check(ok: bool, reason: String) -> void:
    if not ok:
        failures += 1
        push_error(reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.set_process(false)
    game.hero.set_physics_process(false)
    game.expedition.set_physics_process(false)
    game.frontier.set_process(false)
    game.skip_save_on_exit = true
    for enemy in game.enemies: enemy.queue_free()
    game.enemies.clear()
    var actor := CharacterBody3D.new()
    actor.collision_mask = 5
    actor.collision_layer = 0
    var shape := CapsuleShape3D.new()
    shape.radius = .38
    shape.height = 1.5
    var col := CollisionShape3D.new()
    col.shape = shape
    col.position.y = .75
    actor.add_child(col)
    game.add_child(actor)
    game.stockade_built = true
    for level in [1,2]:
        game.base_level = level
        game._build_stockade()
        game.hero.position = Vector3(0,.13,game.gate_front_z())
        game._update_gate(1)
        await physics_frame
        await physics_frame
        for radius in [.38,.62]:
            shape.radius = radius
            shape.height = 1.5 if radius < .4 else 2.3
            col.position.y = shape.height*.5
            var w: float = game.base_half_width()
            var back: float = game.base_back_z()
            var front: float = game.gate_front_z()
            for i in range(115):
                var t: float = float(i)/114
                for side in [-1,1]:
                    actor.position = Vector3(side*(w+2),.13,lerpf(back,front,t))
                    probes += 1
                    check(actor.test_move(actor.global_transform,Vector3(-side*3.5,0,0)),"Perimetro laterale senza varchi, livello %d campione %d" % [level,i])
                for z in [back,front]:
                    var side := -1 if z == back else 1
                    actor.position = Vector3(lerpf(-w,w,t),.13,z+side*2)
                    probes += 1
                    check(actor.test_move(actor.global_transform,Vector3(0,0,-side*3.5)),"Perimetro frontale senza varchi, livello %d campione %d" % [level,i])
            for x in [-1,1]:
                for z in [-1,1]:
                    actor.position = Vector3(x*(w+1.5),.13,(back if z < 0 else front)+z*1.5)
                    check(actor.test_move(actor.global_transform,Vector3(-x*3,0,-z*3)),"Angolo chiuso anche in diagonale")
        # Ogni sezione distrutta deve aprire solo il proprio tratto e richiudersi.
        shape.radius = .38
        shape.height = 1.5
        col.position.y = .75
        for wall in game.wall_segments:
            var at: Vector3 = wall.position
            var side_wall: bool = absf(at.x) > game.base_half_width()-.5
            var outward := Vector3(signf(at.x),0,0) if side_wall else Vector3(0,0,-1 if at.z < 0 else 1)
            actor.position = at+outward*2+Vector3.UP*.13
            wall.hp = 0
            game._sync_structure_visuals()
            await physics_frame
            await physics_frame
            check(not actor.test_move(actor.global_transform,-outward*3.5),"Breccia attraversabile dopo distruzione")
            wall.hp = game.WALL_HP_MAX
            game._sync_structure_visuals()
            await physics_frame
            await physics_frame
            check(actor.test_move(actor.global_transform,-outward*3.5),"Riparazione richiude la stessa breccia")
        # Generazione: punti che prima erano interni all'ampliamento ora respinti.
        for x in range(-8,9):
            for z in range(-11,9):
                var safe: Vector3 = game.safe_enemy_spawn(Vector3(x,.13,z))
                check(not game._inside_stockade(safe),"Nessuna generazione dentro le difese")
        game.elapsed = 100
        for i in range(12):
            game.noise_spawn_cooldown = 0
            for enemy in game.enemies: enemy.queue_free()
            game.enemies.clear()
            game.make_noise(Vector3(0,0,-3),5)
            if not game.enemies.is_empty(): check(not game._inside_stockade(game.enemies.back().position),"Richiamo reale non genera zombie nel cortile")
    for enemy in game.enemies:
        if is_instance_valid(enemy): enemy.set_physics_process(false)
    var alerts = game.alerts
    alerts.presentations = 0
    alerts.last_defense = -100
    alerts.zones.clear()
    game.elapsed = 200
    game.next_raid = 215
    alerts.tick()
    check(alerts.raid_label.visible and alerts.raid_label.text.contains("IN ARRIVO"),"Preavviso orda evidente")
    alerts.raid_started(2)
    for i in range(50): alerts.attacked("EST")
    check(alerts.presentations == 1,"Cinquanta colpi producono un solo avviso")
    check(alerts.raid_label.visible and alerts.defense_label.visible,"Orda e attacco restano distinti")
    alerts.attacked("NORD")
    check(alerts.defense_label.text.contains("EST") and alerts.defense_label.text.contains("NORD"),"Zone aggregate senza notifiche ripetute")
    game.show_message("Bottino",1)
    check(alerts.defense_label.visible,"Il bottino non nasconde gli avvisi")
    game.elapsed += 9
    alerts.tick()
    alerts.attacked("SUD")
    check(alerts.presentations == 2,"Attacchi successivi tornano visibili dopo il limite")
    alerts.attacked("SUD",true)
    check(alerts.defense_label.text.contains("BRECCIA"),"Una breccia supera il limite delle ripetizioni")
    game.wood = 100
    game.manual_target = "wall:0"
    game.hero.position = game.wall_segments[0].position
    game.wall_segments[0].hp = 1
    game._repair_selected("wall:0")
    check(game.wall_segments[0].hp == 240 and game.wood == 88,"Singola riparazione riporta al 100% per 12 legno")
    game.wall_segments[0].hp = 120
    check(game.repair_cost("wall:0") == 6,"Costo proporzionale a meta danno")
    game.wood = 5
    game._repair_selected("wall:0")
    check(game.wall_segments[0].hp == 120 and game.wood == 5 and game.notify_hud.text.contains("Nessuna"),"Risorse insufficienti spiegate e nessuna riparazione parziale")
    for wall in game.wall_segments: wall.hp = 240
    game.wall_segments[0].hp = 120
    game.gate_hp = 140
    game.base_hp = 150
    game.bench_hp = 130
    check(game.repair_all_cost() == 13,"Ripara tutto somma gli stessi costi individuali")
    game.wood = 12
    game._build_or_repair()
    check(game.wall_segments[0].hp == 120 and game.gate_hp == 140 and game.wood == 12,"Ripara tutto insufficiente e atomico")
    game.wood = 13
    game._build_or_repair()
    check(game.wood == 0 and not game._has_damaged_defenses(),"Ripara tutto completo con costo coerente")
    game.queue_free()
    await process_frame
    print("Difese: %d scansioni fisiche, avvisi e riparazioni: %d errori" % [probes,failures])
    quit(1 if failures else 0)
