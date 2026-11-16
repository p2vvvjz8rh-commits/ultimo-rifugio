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
    check(absf(game.camera_yaw) > .1 and game.camera_pitch != game.CAMERA_DEFAULT_PITCH,"Rotella premuta ruota e inclina la camera")
    for drag in range(10):
        game._orbit_camera(Vector2(1000,1000))
    check(game.camera_pitch <= game.CAMERA_MAX_PITCH and game.camera_pitch >= game.CAMERA_MIN_PITCH,"Inclinazione limitata senza ribaltamenti")
    game.camera_pitch = game.CAMERA_DEFAULT_PITCH
    for angle in [0.0,PI*.5,PI,-PI*.5]:
        game.camera_yaw = angle
        game._update_camera(1)
        var offset: Vector3 = game.camera.global_position-game.camera_focus
        check(is_equal_approx(offset.length(),game.CAMERA_ORBIT_RADIUS*game.camera_distance),"Orbita mantiene la distanza in tutti i quadranti")
        var projected: Vector2 = game.camera.unproject_position(game.camera_focus)
        var center: Vector2 = game.get_viewport().get_visible_rect().size*.5
        check(projected.distance_to(center) < 2,"Il protagonista resta al centro durante il giro completo")
    game.camera_yaw = 0
    game._update_camera(1)
    game.camera_yaw = PI
    for frame in range(60):
        game._update_camera(1.0/60)
        check(game.camera.global_position.distance_to(game.camera_focus) > game.CAMERA_ORBIT_RADIUS*game.camera_distance*.99,"La transizione non attraversa il protagonista")
    game.camera_yaw = PI-.01
    game.camera_yaw_current = PI-.01
    game._orbit_camera(Vector2(-10,0))
    game._update_camera(.01)
    check(absf(angle_difference(PI-.01,game.camera_yaw_current)) < .1,"Passaggio attraverso 360 gradi continuo")
    var left := InputEventMouseButton.new()
    left.button_index = MOUSE_BUTTON_LEFT
    left.pressed = true
    left.position = Vector2(500,400)
    game._unhandled_input(left)
    check(not game.hero.mouse_has_destination and game.hero.global_position.is_equal_approx(hero_before),"Muovere la camera non comanda il protagonista")
    middle.pressed = false
    game._input(middle)
    check(not game.camera_dragging,"Rilascio rotella termina il trascinamento")
    middle.pressed = true
    game._input(middle)
    game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    check(not game.camera_dragging,"La perdita del focus libera il trascinamento")
    var home := InputEventKey.new()
    home.keycode = KEY_HOME
    home.pressed = true
    game._input(home)
    check(game.camera_yaw == 0 and game.camera_pitch == game.CAMERA_DEFAULT_PITCH,"Home ripristina orientamento e inclinazione")
    game.paused = true
    game.camera_yaw = PI*.5
    var previous_position: Vector3 = game.camera.global_position
    var elapsed: float = game.elapsed
    game._process(.2)
    check(not game.camera.global_position.is_equal_approx(previous_position) and game.elapsed == elapsed,"In pausa la camera ruota senza avanzare il gioco")
    var zoom_before: float = game.camera_distance
    var wheel := InputEventMouseButton.new()
    wheel.button_index = MOUSE_BUTTON_WHEEL_UP
    wheel.pressed = true
    game._unhandled_input(wheel)
    check(game.camera_distance < zoom_before,"La rotella mantiene lo zoom anche in pausa")
    game.paused = false
    game.camera_yaw_current = PI*.5
    game.hero.position = Vector3(12,.13,12)
    game.hero.set_physics_process(true)
    var key := InputEventKey.new()
    key.keycode = KEY_W
    key.physical_keycode = KEY_W
    key.pressed = true
    Input.parse_input_event(key)
    for frame in range(20):
        await physics_frame
    key.pressed = false
    Input.parse_input_event(key)
    game.hero.set_physics_process(false)
    check(game.hero.position.x < 11.5 and absf(game.hero.position.z-12) < .1,"W avanza rispetto alla camera ruotata, non rispetto al nord del mondo")
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
