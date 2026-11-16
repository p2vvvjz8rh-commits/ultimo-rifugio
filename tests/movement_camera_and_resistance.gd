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
    game.salvage.set_process(false)
    game.radio_station.set_process(false)
    game.trees.clear()
    for enemy in game.enemies:
        enemy.queue_free()
    game.enemies.clear()
    game.stockade_built = true
    game._build_stockade()
    game.hero.global_position = Vector3(4.2,.1,0)
    game.hero.set_mouse_destination(Vector3(8,.1,0))
    for frame in range(100):
        await physics_frame
    var stuck_position: Vector3 = game.hero.global_position
    check(stuck_position.x < 4.8,"Il personaggio e' bloccato fisicamente dal muro")
    check(game.hero.visual.current_clip.to_lower().ends_with("idle"),"Contro il muro la locomozione passa a Idle")
    game.hero.set_mouse_destination(Vector3(8,.1,2))
    for frame in range(12):
        await physics_frame
    check(game.hero.global_position.z > stuck_position.z+.2,"Lo scorrimento lungo il muro resta possibile")
    check(game.hero.visual.current_clip.to_lower().ends_with("walk"),"Movimento reale lungo il muro mantiene Walk")
    game.hero.set_physics_process(false)
    game.hero.clear_mouse_destination()
    game._update_camera(1)
    var hero_before: Vector3 = game.hero.global_position
    var middle := InputEventMouseButton.new()
    middle.button_index = MOUSE_BUTTON_MIDDLE
    middle.pressed = true
    game._input(middle)
    var motion := InputEventMouseMotion.new()
    motion.relative = Vector2(120,-60)
    game._input(motion)
    check(game.camera_pan.length() > .1 and game.camera_pan.length() <= game.CAMERA_PAN_LIMIT+.001,"Trascinamento rotella sposta l'inquadratura entro il limite")
    for drag in range(10):
        game._pan_camera(Vector2(1000,1000))
    check(game.camera_pan.length() <= game.CAMERA_PAN_LIMIT+.001,"Limite mantenuto anche dopo trascinamenti ripetuti")
    var left := InputEventMouseButton.new()
    left.button_index = MOUSE_BUTTON_LEFT
    left.pressed = true
    left.position = Vector2(500,400)
    game._unhandled_input(left)
    check(not game.hero.mouse_has_destination and game.hero.global_position.is_equal_approx(hero_before),"Muovere la camera non comanda il protagonista")
    middle.pressed = false
    game._input(middle)
    check(not game.camera_dragging,"Rilascio rotella termina il trascinamento")
    var home := InputEventKey.new()
    home.keycode = KEY_HOME
    home.pressed = true
    game._input(home)
    check(game.camera_pan == Vector3.ZERO,"Home ricentra la visuale")
    game.paused = true
    game.camera_pan = Vector3(3,0,4)
    var previous_focus: Vector3 = game.camera_focus
    var elapsed: float = game.elapsed
    game._process(.2)
    check(not game.camera_focus.is_equal_approx(previous_focus) and game.elapsed == elapsed,"In pausa la camera si muove senza avanzare il gioco")
    var zoom_before: float = game.camera_distance
    var wheel := InputEventMouseButton.new()
    wheel.button_index = MOUSE_BUTTON_WHEEL_UP
    wheel.pressed = true
    game._unhandled_input(wheel)
    check(game.camera_distance < zoom_before,"La rotella mantiene lo zoom anche in pausa")
    game.paused = false
    game.base_hp = game.CABIN_HP_MAX
    game.damage_base(20)
    check(is_equal_approx(game.base_hp,143.0),"Capanna: danno ridotto del 65%, HP massimi invariati")
    game._save_progress()
    game.base_hp = 1
    game._load_progress()
    check(is_equal_approx(game.base_hp,143.0),"Salvataggi conservano gli HP senza migrazioni")
    game.wall_segments[0]["hp"] = 50.0
    game._sync_structure_visuals()
    var component = game.wall_segments[0]["durability"]
    var fractured_count: int = 0
    var pending: Array = [component.bound_meshes[0]["variants"][1]]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        pending.append_array(node.get_children())
        if node is MeshInstance3D and node.get_meta("damaged_structure",false):
            fractured_count += 1
            check(node.material_override.cull_mode == BaseMaterial3D.CULL_DISABLED,"Fratture visibili da entrambi i lati")
            check(game._occlusion_opacity(node) >= .6,"Trasparenza mantiene leggibili i danni dall'interno")
    check(fractured_count > 0,"Verificata geometria effettiva danneggiata")
    game.skip_save_on_exit = true
    game.queue_free()
    await process_frame
    print("Movimento, camera e resistenza: %d errori" % failures)
    quit(1 if failures else 0)
