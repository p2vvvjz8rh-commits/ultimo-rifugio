extends Node3D
## ALFA 08 - piccola radura 3D nativa.
## Asset e animazioni Quaternius glTF, senza conversione in sprite.

const FENCE_COST := 45
const REPAIR_COST := 18
const FIRST_RAID_TIME := 120.0
const WORLD_HALF := 22.0

var rng := RandomNumberGenerator.new()
var materials := {}
var hero
var enemies: Array = []
var trees: Array = []
var camera: Camera3D
var fence_root: Node3D
var gate_left: Node3D
var gate_right: Node3D
var gate_left_collision: CollisionShape3D
var gate_right_collision: CollisionShape3D
var top_hud: Label
var objective_hud: Label
var notify_hud: Label
var info_hud: Label
var build_button: Button
var upgrade_button: Button
var special_button: Button
var dodge_button: Button
var wood: int = 0
var coins: int = 0
var kills: int = 0
var weapon_level: int = 1
var base_hp: float = 150.0
var elapsed: float = 0.0
var next_raid: float = FIRST_RAID_TIME
var raid_number: int = 0
var stockade_built: bool = false
var gate_broken: bool = false
var paused: bool = false
var noise_time: float = 0.0
var noise_position := Vector3.ZERO
var message_time: float = 0.0
var save_time: float = 0.0
var last_mouse_button: bool = false
var current_gate_open := 0.0

func _ready() -> void:
    rng.seed = 20261114
    _create_environment()
    _create_ground()
    _create_cabin()
    _create_forest()
    _create_hero()
    _create_camera()
    _create_hud()
    _load_progress()
    _spawn_initial_enemies()
    show_message("Esplora la radura. Zombie prima, raccolta del legno poi!", 5.0)

func _process(delta: float) -> void:
    if paused:
        return
    if last_mouse_button and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        last_mouse_button = false
    elapsed += delta
    save_time += delta
    message_time -= delta
    noise_time = maxf(0.0, noise_time - delta)
    if message_time <= 0.0:
        notify_hud.text = ""
    if elapsed >= next_raid:
        _start_raid()
    _regrow_trees()
    _update_gate(delta)
    _update_camera(delta)
    _update_hud()
    enemies = enemies.filter(func(enemy): return is_instance_valid(enemy))
    if save_time > 12.0:
        save_time = 0.0
        _save_progress()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                paused = not paused
                show_message("IN PAUSA - premi ESC per riprendere" if paused else "Esplorazione ripresa", 2.5)
            KEY_Q:
                if not paused:
                    hero.special_attack()
            KEY_SPACE:
                if not paused:
                    hero.dash()
            KEY_B:
                if not paused:
                    _build_or_repair()
            KEY_U:
                if not paused:
                    _upgrade_weapon()
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            last_mouse_button = event.pressed
    if event is InputEventMouseMotion and last_mouse_button and not paused:
        _move_by_cursor(event.position)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not paused:
        _move_by_cursor(event.position)

func _move_by_cursor(cursor: Vector2) -> void:
    var ray_origin := camera.project_ray_origin(cursor)
    var ray_dir := camera.project_ray_normal(cursor)
    var terrain_plane := Plane(Vector3.UP, 0.0)
    var point = terrain_plane.intersects_ray(ray_origin, ray_dir)
    if point != null:
        hero.set_mouse_destination(point)

func _mat(hex_color: String, roughness: float = 0.87) -> StandardMaterial3D:
    if materials.has(hex_color):
        return materials[hex_color]
    var result := StandardMaterial3D.new()
    result.albedo_color = Color.html(hex_color)
    result.roughness = roughness
    materials[hex_color] = result
    return result

func _box(parent: Node3D, title: String, pos: Vector3, size: Vector3, color_hex: String, angle_z: float = 0.0) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    instance.name = title
    instance.mesh = shape
    instance.material_override = _mat(color_hex)
    instance.position = pos
    instance.rotation.z = angle_z
    parent.add_child(instance)
    return instance

func _cone(parent: Node3D, title: String, pos: Vector3, radius: float, height: float, color_hex: String, top_radius: float = 0.0) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var shape := CylinderMesh.new()
    shape.bottom_radius = radius
    shape.top_radius = top_radius
    shape.height = height
    shape.radial_segments = 7
    instance.name = title
    instance.mesh = shape
    instance.material_override = _mat(color_hex)
    instance.position = pos
    parent.add_child(instance)
    return instance

func _rock(parent: Node3D, title: String, pos: Vector3, scale_3d: Vector3, color_hex: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var shape := SphereMesh.new()
    shape.radius = 0.55
    shape.height = 1.05
    shape.radial_segments = 7
    shape.rings = 4
    instance.name = title
    instance.mesh = shape
    instance.material_override = _mat(color_hex)
    instance.position = pos
    instance.scale = scale_3d
    parent.add_child(instance)
    return instance

func _create_environment() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("#8bb8b2")
    sky_material.sky_horizon_color = Color("#c5d5ba")
    sky_material.ground_bottom_color = Color("#365b46")
    sky_material.ground_horizon_color = Color("#9fac80")
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.65
    world_environment.environment = environment
    add_child(world_environment)
    var sun := DirectionalLight3D.new()
    sun.name = "Sole_del_pomeriggio"
    sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
    sun.light_color = Color("#ffe3ad")
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    add_child(sun)

func _create_ground() -> void:
    var ground := StaticBody3D.new()
    ground.name = "Terreno"
    add_child(ground)
    _box(ground, "Prato", Vector3(0, -0.22, 0), Vector3(48, 0.4, 48), "#628657")
    var collider := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3(48, 0.4, 48)
    collider.shape = box_shape
    collider.position = Vector3(0, -0.22, 0)
    ground.add_child(collider)
    # Terra battuta nel cortile e sentiero di accesso alla foresta.
    _box(self, "Cortile", Vector3(0, 0.012, -2.0), Vector3(10.6, 0.05, 12.5), "#73905a")
    for index in range(11):
        var z := 4.5 + float(index) * 1.48
        _box(self, "Sentiero_%02d" % index, Vector3(sin(float(index) * 0.65) * 0.48, 0.012, z), Vector3(1.8, 0.025, 1.17), "#98845d")
    for i in range(230):
        var x := rng.randf_range(-22.5, 22.5)
        var z := rng.randf_range(-22.5, 22.5)
        if absf(x) < 5.0 and z > -8.0 and z < 4.8:
            continue
        if rng.randf() < 0.18:
            _rock(self, "Ciottolo", Vector3(x, 0.07, z), Vector3(rng.randf_range(.13,.33), .13, rng.randf_range(.16,.38)), "#879080")
        else:
            var grass := _cone(self, "Ciuffo_d_erba", Vector3(x, 0.13, z), 0.075, rng.randf_range(0.15, 0.28), "#83a76b")
            grass.rotation.z = rng.randf_range(-0.3, 0.3)

func _create_cabin() -> void:
    var base := Node3D.new()
    base.name = "Rifugio"
    base.position = Vector3(0, 0, -3.6)
    add_child(base)
    _box(base, "Fondamenta", Vector3(0, 0.14, 0), Vector3(4.8, .28, 4.8), "#676452")
    _box(base, "Pareti", Vector3(0, 1.28, 0), Vector3(3.75, 2.45, 3.75), "#a47d56")
    for z in [-1.90, 1.90]:
        _box(base, "Trave", Vector3(-1.74, 1.22, z), Vector3(.16, 2.4, .18), "#684833")
        _box(base, "Trave", Vector3(1.74, 1.22, z), Vector3(.16, 2.4, .18), "#684833")
    _box(base, "Tetto_sinistro", Vector3(-1.02, 2.79, 0.0), Vector3(2.55, .17, 4.5), "#425a65", -0.36)
    _box(base, "Tetto_destro", Vector3(1.02, 2.79, 0.0), Vector3(2.55, .17, 4.5), "#354c55", 0.36)
    _box(base, "Porta", Vector3(0, .85, 1.90), Vector3(.98, 1.62, .14), "#45372b")
    _cone(base, "Maniglia", Vector3(.35, .84, 2.02), .055, .065, "#e4b46e", .055)
    for dx in [-1.0, 1.0]:
        _box(base, "Finestra", Vector3(dx, 1.65, 1.91), Vector3(.53, .55, .11), "#f6c56e")
        _box(base, "Infisso_verticale", Vector3(dx, 1.65, 1.98), Vector3(.055, .60, .08), "#513c2b")
    _box(base, "Portico", Vector3(0, .14, 2.95), Vector3(2.9, .19, 1.8), "#806047")
    for i in range(6):
        _box(base, "Asse_portico", Vector3(-1.2 + i*.47,.27,2.94), Vector3(.40,.04,1.68), "#ac8860")
    # Camino, catasta di legna e falò.
    _box(base, "Camino", Vector3(1.25, 3.05, -.85), Vector3(.54, 1.0, .55), "#8a8a83")
    for i in range(4):
        _box(base, "Legna_accatastata", Vector3(2.55, .17 + i*.15, -1.35), Vector3(.95, .14, .21), "#8b603f")
    _cone(base,"Falò_1",Vector3(0, .50, 5.4), .46, .85,"#e99547")
    _cone(base,"Falò_2",Vector3(0, .67, 5.4), .28, .71,"#ffce6e")
    for j in range(8):
        var a = float(j) * TAU / 8
        _rock(base,"Pietra_falò",Vector3(cos(a)*.65,.13,5.4+sin(a)*.65),Vector3(.45,.26,.42),"#7d8076")
    var flame_light := OmniLight3D.new()
    flame_light.name = "Luce_del_fuoco"
    flame_light.position = Vector3(0, 1.3, 5.4)
    flame_light.light_color = Color("#ffb66c")
    flame_light.light_energy = 0.5
    flame_light.omni_range = 6.0
    base.add_child(flame_light)

func _create_forest() -> void:
    # Alberi ravvicinati rigenerabili per testare la raccolta; altri intorno alla radura.
    var near_positions := [Vector2(-7.0, 3.6), Vector2(-8.2, 7.2), Vector2(7.4, 5.3), Vector2(9.0, .9), Vector2(-7.8, -5.9), Vector2(8.0, -7.6)]
    for p in near_positions:
        _create_tree(p.x, p.y, rng.randf_range(.88, 1.12), true)
    for i in range(70):
        var pos := Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
        if absf(pos.x) < 6.6 and pos.y > -9.0 and pos.y < 7.8:
            continue
        if pos.length() < 10.5 and rng.randf() < .75:
            continue
        _create_tree(pos.x, pos.y, rng.randf_range(.85, 1.5), true)
    for i in range(33):
        var x := rng.randf_range(-20,20)
        var z := rng.randf_range(-20,20)
        if absf(x) < 7 and absf(z + 2.0) < 9:
            continue
        _rock(self,"Roccia",Vector3(x,.21,z), Vector3(rng.randf_range(.55,1.6),rng.randf_range(.35,.8),rng.randf_range(.7,1.4)),"#858e7d")

func _create_tree(x: float, z: float, scale_factor: float, harvestable: bool) -> void:
    var tree := Node3D.new()
    tree.name = "Abete_raccoglibile" if harvestable else "Abete"
    tree.position = Vector3(x, 0, z)
    tree.scale = Vector3.ONE * scale_factor
    add_child(tree)
    _cone(tree,"Tronco",Vector3(0,1.00,0),.21,2.0,"#765339", .18)
    _cone(tree,"Rami_bassi",Vector3(0,2.25,0),1.45,2.35,"#2d654d")
    _cone(tree,"Rami_medi",Vector3(0,3.15,0),1.12,1.97,"#377d58")
    _cone(tree,"Rami_alti",Vector3(0,3.96,0),.79,1.66,"#468d60")
    _cone(tree,"Punta",Vector3(0,4.62,0),.49,1.13,"#52986e")
    var stump := _cone(self,"Ceppo",Vector3(x,.14,z),.30 * scale_factor,.3,"#9e784e", .30 * scale_factor)
    stump.visible = false
    trees.append({"node":tree,"stump":stump,"hp":3,"regrow_at":0.0,"harvestable":harvestable})

func _create_hero() -> void:
    hero = preload("res://scripts/survivor.gd").new()
    add_child(hero)
    hero.global_position = Vector3(0, 0.10, 7.0)
    hero.configure(self)

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.name = "Telecamera_inclinata"
    camera.current = true
    camera.fov = 47.0
    camera.position = hero.global_position + Vector3(0, 14.5, 16.5)
    add_child(camera)
    camera.look_at(hero.global_position + Vector3(0, 1.15, -1.9), Vector3.UP)

func _update_camera(delta: float) -> void:
    var desired: Vector3 = hero.global_position + Vector3(0, 14.5, 16.5)
    camera.global_position = camera.global_position.lerp(desired, clampf(delta * 3.0, 0.0, 1.0))
    camera.look_at(hero.global_position + Vector3(0, 1.15, -2.0), Vector3.UP)

func _spawn_initial_enemies() -> void:
    _spawn_enemy(Vector3(-11, .13, 10), "normal", false)
    _spawn_enemy(Vector3(12, .13, 9), "normal", false)
    _spawn_enemy(Vector3(13, .13, -9), "runner", false)

func _spawn_enemy(at: Vector3, variant: String, wave: bool) -> void:
    var mob = preload("res://scripts/zombie.gd").new()
    add_child(mob)
    mob.global_position = at
    mob.configure(self, variant, wave)
    enemies.append(mob)

func closest_enemy(position_3d: Vector3, radius: float):
    var best = null
    var best_distance := radius
    for enemy in enemies:
        if not is_instance_valid(enemy) or enemy.defeated:
            continue
        var distance := position_3d.distance_to(enemy.global_position)
        if distance < best_distance:
            best = enemy
            best_distance = distance
    return best

func closest_tree(position_3d: Vector3, radius: float):
    var nearest = null
    var nearest_dist := radius
    for t in trees:
        if t["hp"] <= 0 or not t["harvestable"]:
            continue
        var d: float = position_3d.distance_to(t["node"].global_position)
        if d < nearest_dist:
            nearest_dist = d
            nearest = t
    return nearest

func _floating_tree_number(at: Vector3, content: String, reward: bool = false) -> void:
    # Indicatore 3D sopra l'albero: sempre visibile indipendentemente dalla telecamera.
    var label := Label3D.new()
    label.name = "Numero_colpo_albero"
    label.text = content
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.font_size = 46 if reward else 39
    label.pixel_size = 0.007
    label.outline_size = 8
    label.modulate = Color("#ffe09a") if reward else Color("#f5f2d8")
    label.outline_modulate = Color("#22362d")
    label.position = at + Vector3(0.0, 2.65, 0.0)
    add_child(label)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "position", label.position + Vector3(0.0, 0.82, 0.0), 0.95)
    tween.tween_property(label, "modulate:a", 0.0, 0.95)
    tween.set_parallel(false)
    tween.tween_callback(Callable(label, "queue_free"))

func chop_tree(t: Dictionary) -> void:
    t["hp"] = int(t["hp"]) - 1
    var tree_pos: Vector3 = t["node"].global_position
    make_noise(tree_pos, 4.0)
    if int(t["hp"]) <= 0:
        t["node"].visible = false
        t["stump"].visible = true
        t["regrow_at"] = elapsed + rng.randf_range(32.0, 48.0)
        wood += 9
        _floating_tree_number(tree_pos, "+9 LEGNO", true)
        show_message("+9 LEGNO", 1.2)
    else:
        # Numero di colpi ancora necessari, ad es. 2/3 e 1/3.
        _floating_tree_number(tree_pos, "%d/3" % int(t["hp"]))

func _regrow_trees() -> void:
    for t in trees:
        if t["hp"] > 0 or elapsed < t["regrow_at"]:
            continue
        var occupied := false
        if hero.global_position.distance_to(t["node"].global_position) < 1.6:
            occupied = true
        for enemy in enemies:
            if is_instance_valid(enemy) and not enemy.defeated and enemy.global_position.distance_to(t["node"].global_position) < 1.5:
                occupied = true
        if occupied:
            t["regrow_at"] = elapsed + 4.0
        else:
            t["hp"] = 3
            t["node"].visible = true
            t["stump"].visible = false

func make_noise(where: Vector3, duration: float) -> void:
    noise_position = where
    noise_time = duration

func _start_raid() -> void:
    raid_number += 1
    var count := mini(11, 3 + raid_number * 2)
    for i in range(count):
        var a := float(i) * TAU / float(count) + rng.randf_range(-.15,.15)
        var radius := rng.randf_range(13.0, 17.0)
        var variant := "runner" if i % 4 == 0 and raid_number >= 2 else "normal"
        _spawn_enemy(Vector3(cos(a) * radius, .13, sin(a) * radius), variant, true)
    if raid_number >= 2:
        _spawn_enemy(Vector3(15.5, .13, 2.0), "brute", true)
    next_raid = elapsed + maxf(162.0, 181.0 - float(raid_number) * 4.0)
    show_message("⚠ ORDA %d — RIENTRA AL RIFUGIO!" % raid_number, 5.0)

func _build_or_repair() -> void:
    if not stockade_built:
        if wood < FENCE_COST:
            show_message("Servono %d legno per il recinto." % FENCE_COST, 2.0)
            return
        wood -= FENCE_COST
        stockade_built = true
        base_hp = 150.0
        _build_stockade()
        show_message("PALIZZATA + CANCELLO COSTRUITI!", 3.0)
    elif base_hp < 150.0 or gate_broken:
        if wood < REPAIR_COST:
            show_message("Servono %d legno per la riparazione." % REPAIR_COST, 2.0)
            return
        wood -= REPAIR_COST
        base_hp = 150.0
        gate_broken = false
        show_message("Palizzata riparata.", 2.3)
    else:
        show_message("Palizzata già integra.", 1.7)
    _save_progress()

func _build_stockade() -> void:
    if fence_root != null and is_instance_valid(fence_root):
        fence_root.queue_free()
    fence_root = Node3D.new()
    fence_root.name = "Palizzata_automatica"
    add_child(fence_root)
    var left_x := -5.3
    var right_x := 5.3
    var back_z := -7.9
    var front_z := 4.0
    for i in range(22):
        var x := left_x + float(i) * (right_x-left_x) / 21.0
        _post(fence_root, Vector3(x,0,back_z))
        if absf(x) > 1.12:
            _post(fence_root, Vector3(x,0,front_z))
    for i in range(23):
        var z := back_z + float(i)*(front_z-back_z)/22.0
        _post(fence_root, Vector3(left_x,0,z))
        _post(fence_root, Vector3(right_x,0,z))
    _box(fence_root,"Architrave_1",Vector3(-5.3,1.05,-1.9),Vector3(.22,.26,12),"#674a32")
    _box(fence_root,"Architrave_2",Vector3(5.3,1.05,-1.9),Vector3(.22,.26,12),"#674a32")
    _box(fence_root,"Architrave_3",Vector3(0,1.05,-7.9),Vector3(10.8,.26,.22),"#674a32")
    _box(fence_root,"Architrave_4",Vector3(-3.17,1.05,4.0),Vector3(4.25,.26,.22),"#674a32")
    _box(fence_root,"Architrave_5",Vector3(3.17,1.05,4.0),Vector3(4.25,.26,.22),"#674a32")
    _box(fence_root,"Montante_cancello_SX",Vector3(-1.17,1.26,4),Vector3(.32,2.6,.38),"#6c482d")
    _box(fence_root,"Montante_cancello_DX",Vector3(1.17,1.26,4),Vector3(.32,2.6,.38),"#6c482d")
    gate_left = Node3D.new()
    gate_left.name = "Anta_SX"
    gate_left.position = Vector3(-1.08, 0.0, 4.0)
    fence_root.add_child(gate_left)
    _box(gate_left,"Legno_anta",Vector3(.53,1.03,0),Vector3(1.07,2.08,.22),"#997048")
    _box(gate_left,"Rinforzo",Vector3(.53,.75,.15),Vector3(1.07,.16,.12),"#533b29")
    gate_right = Node3D.new()
    gate_right.name = "Anta_DX"
    gate_right.position = Vector3(1.08, 0.0, 4.0)
    fence_root.add_child(gate_right)
    _box(gate_right,"Legno_anta",Vector3(-.53,1.03,0),Vector3(1.07,2.08,.22),"#997048")
    _box(gate_right,"Rinforzo",Vector3(-.53,.75,.15),Vector3(1.07,.16,.12),"#533b29")
    for x in [-5.3, 5.3]:
        for z in [back_z, front_z]:
            _cone(fence_root,"Palo_angolare",Vector3(x,1.75,z),.37,3.5,"#7f5838",.17)
    # Le tavole sono solo grafica. Queste cinque superfici fisiche chiudono
    # tutto il recinto, lasciando libero unicamente il vano del cancello.
    _wall_collision("Parete_posteriore", Vector3(0.0,1.12,back_z), Vector3(10.95,2.24,.50))
    _wall_collision("Parete_sinistra", Vector3(left_x,1.12,-1.95), Vector3(.50,2.24,12.40))
    _wall_collision("Parete_destra", Vector3(right_x,1.12,-1.95), Vector3(.50,2.24,12.40))
    _wall_collision("Parete_frontale_sinistra", Vector3(-3.19,1.12,front_z), Vector3(4.32,2.24,.50))
    _wall_collision("Parete_frontale_destra", Vector3(3.19,1.12,front_z), Vector3(4.32,2.24,.50))
    # Anche le ante hanno collider, legati allo stesso nodo che ruota.
    gate_left_collision = _gate_collision(gate_left, "Collider_anta_sinistra", Vector3(.53,1.03,0.0))
    gate_right_collision = _gate_collision(gate_right, "Collider_anta_destra", Vector3(-.53,1.03,0.0))
    _sync_gate_collision(false)

func _wall_collision(title: String, center: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = "Blocco_recinto_" + title
    body.collision_layer = 1 # Sia il giocatore sia gli zombie usano collision_mask = 1.
    body.collision_mask = 0
    body.add_to_group("palizzata_solida")
    fence_root.add_child(body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    collider.position = center
    body.add_child(collider)

func _gate_collision(leaf: Node3D, title: String, offset: Vector3) -> CollisionShape3D:
    var body := StaticBody3D.new()
    body.name = title
    body.collision_layer = 1
    body.collision_mask = 0
    body.add_to_group("palizzata_solida")
    leaf.add_child(body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.07,2.07,.23)
    collider.shape = shape
    collider.position = offset
    body.add_child(collider)
    return collider

func _sync_gate_collision(is_open: bool) -> void:
    # Disabilita soltanto le ante, mai i cinque blocchi delle mura.
    var blocking: bool = not is_open and not gate_broken
    if is_instance_valid(gate_left_collision):
        gate_left_collision.set_deferred("disabled", not blocking)
    if is_instance_valid(gate_right_collision):
        gate_right_collision.set_deferred("disabled", not blocking)

func wall_assault_target(from_position: Vector3) -> Vector3:
    # Gli zombie delle orde si distribuiscono sui lati, invece di camminare
    # indefinitamente contro il muro verso il centro del cortile.
    if not stockade_built or gate_broken:
        return Vector3(0.0,0.0,3.8)
    var candidate_points: Array[Vector3] = [
        Vector3(-5.3,0.0,clampf(from_position.z,-7.9,4.0)),
        Vector3(5.3,0.0,clampf(from_position.z,-7.9,4.0)),
        Vector3(clampf(from_position.x,-5.3,5.3),0.0,-7.9),
        Vector3(clampf(from_position.x,-5.3,5.3),0.0,4.0)
    ]
    var nearest: Vector3 = candidate_points[0]
    var shortest: float = INF
    for point in candidate_points:
        var horizontal: Vector2 = Vector2(from_position.x-point.x,from_position.z-point.z)
        var distance_squared: float = horizontal.length_squared()
        if distance_squared < shortest:
            shortest = distance_squared
            nearest = point
    return nearest

func _post(parent: Node3D, pos: Vector3) -> void:
    _box(parent,"Asse",pos+Vector3(0,.94,0),Vector3(.43,1.84,.42),"#9b7349")
    _cone(parent,"Punta",pos+Vector3(0,2.06,0),.31,.54,"#c49256",0.0)

func _update_gate(delta: float) -> void:
    if not stockade_built or gate_left == null or gate_right == null:
        return
    var open_target := 1.0 if hero.global_position.distance_to(Vector3(0,0,4.1)) < 3.0 else 0.0
    current_gate_open = move_toward(current_gate_open,open_target,delta*1.65)
    gate_left.rotation.y = current_gate_open * -1.35
    gate_right.rotation.y = current_gate_open * 1.35
    gate_left.visible = not gate_broken
    gate_right.visible = not gate_broken
    # Appena l'apertura e' attivata, le ante smettono di bloccare il passaggio.
    # Mentre si richiudono restano attraversabili fino a completa chiusura.
    var passable: bool = gate_broken or open_target > 0.5 or current_gate_open > 0.03
    _sync_gate_collision(passable)

func damage_base(damage: float) -> void:
    base_hp -= damage
    if base_hp <= 0.0:
        base_hp = 150.0
        gate_broken = true
        wood = maxi(0, wood - 10)
        show_message("Difese danneggiate! Per riparare servono 18 legno.", 3.0)

func _upgrade_weapon() -> void:
    if weapon_level >= 4:
        show_message("Arma al livello massimo della prova.", 1.5)
        return
    var cost := 12 + (weapon_level - 1) * 14
    if coins < cost:
        show_message("Servono %d monete." % cost, 1.8)
        return
    coins -= cost
    weapon_level += 1
    show_message("Bastone potenziato al livello %d!" % weapon_level, 1.8)
    _save_progress()

func _make_panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.065,0.13,0.12,0.9)
    style.border_color = Color(.76,.69,.46,.56)
    style.set_border_width_all(1)
    style.set_corner_radius_all(13)
    style.content_margin_left = 15
    style.content_margin_right = 15
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _label(parent: Control, content: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = content
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _create_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "Interfaccia"
    add_child(layer)
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)
    var left := PanelContainer.new()
    left.position = Vector2(18,18)
    left.custom_minimum_size = Vector2(250,126)
    left.add_theme_stylebox_override("panel",_make_panel_style())
    root.add_child(left)
    var left_vbox := VBoxContainer.new()
    left.add_child(left_vbox)
    _label(left_vbox,"ULTIMO RIFUGIO · ALFA 08",13,Color("#e6bb77"))
    top_hud = _label(left_vbox,"VITA 100/100    LEGNO 0    MONETE 0",18,Color("#fff1cf"))
    info_hud = _label(left_vbox,"Rifugio: 150/150",13,Color("#c2d2ba"))
    var objective_panel := PanelContainer.new()
    objective_panel.anchor_left = 0.5
    objective_panel.anchor_right = 0.5
    objective_panel.offset_left = -218
    objective_panel.offset_right = 218
    objective_panel.offset_top = 18
    objective_panel.offset_bottom = 108
    objective_panel.add_theme_stylebox_override("panel",_make_panel_style())
    root.add_child(objective_panel)
    var objective_vbox := VBoxContainer.new()
    objective_panel.add_child(objective_vbox)
    _label(objective_vbox,"PROSSIMO OBIETTIVO",12,Color("#e5b967"))
    objective_hud = _label(objective_vbox,"Esplora e prepara le difese",16,Color("#fff1cf"))
    notify_hud = _label(objective_vbox,"",13,Color("#f0c089"))
    var bottom := HBoxContainer.new()
    bottom.anchor_left = 0.5
    bottom.anchor_right = 0.5
    bottom.anchor_top = 1.0
    bottom.anchor_bottom = 1.0
    bottom.offset_left = -330
    bottom.offset_right = 330
    bottom.offset_top = -84
    bottom.offset_bottom = -16
    bottom.add_theme_constant_override("separation",9)
    root.add_child(bottom)
    build_button = _button(bottom,"RECINTO · 45 LEGNO")
    build_button.pressed.connect(_build_or_repair)
    upgrade_button = _button(bottom,"ARMA · 12 MONETE")
    upgrade_button.pressed.connect(_upgrade_weapon)
    special_button = _button(bottom,"COLPO AMPIO · Q")
    special_button.pressed.connect(func(): hero.special_attack())
    dodge_button = _button(bottom,"SCHIVA · SPAZIO")
    dodge_button.pressed.connect(func(): hero.dash())
    var guide := _label(root,"WASD / frecce o mouse premuto: muovi   •   Zombie: attacco automatico   •   Alberi: raccolta automatica   •   ESC: pausa",12,Color("#f0e3bb"))
    guide.anchor_top = 1.0
    guide.anchor_bottom = 1.0
    guide.offset_left = 18
    guide.offset_top = -113
    guide.offset_bottom = -90

func _button(parent: Control, caption: String) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(156,54)
    button.add_theme_font_size_override("font_size",12)
    parent.add_child(button)
    return button

func _update_hud() -> void:
    top_hud.text = "VITA %d/100    LEGNO %d    MONETE %d" % [ceili(hero.hp),wood,coins]
    info_hud.text = "RIFUGIO: %d/150   |   ARMA Lv.%d   |   UCCISIONI %d" % [ceili(base_hp),weapon_level,kills]
    var remain := maxi(0, ceili(next_raid - elapsed))
    objective_hud.text = "Esplora e costruisci   ·   ORDA IN %d:%02d" % [int(remain / 60), remain % 60]
    if not stockade_built:
        build_button.text = "RECINTO · %d LEGNO" % FENCE_COST
        build_button.disabled = wood < FENCE_COST
    else:
        build_button.text = "RIPARA · %d LEGNO" % REPAIR_COST if base_hp < 150.0 or gate_broken else "RECINTO COMPLETO"
        build_button.disabled = (wood < REPAIR_COST) or (base_hp >= 150.0 and not gate_broken)
    var cost := 12 + (weapon_level - 1) * 14
    upgrade_button.text = "ARMA Lv.%d · %d MON." % [weapon_level,cost] if weapon_level < 4 else "ARMA MASSIMA"
    upgrade_button.disabled = coins < cost or weapon_level >= 4
    special_button.disabled = hero.special_cooldown > 0.0
    dodge_button.disabled = hero.dash_cooldown > 0.0

func show_message(message: String, duration: float = 2.5) -> void:
    if notify_hud == null:
        return
    notify_hud.text = message
    message_time = duration

func _save_directory() -> String:
    if OS.has_feature("standalone"):
        return OS.get_executable_path().get_base_dir().path_join("salvataggi")
    return ProjectSettings.globalize_path("user://salvataggi")

func _save_progress() -> void:
    var directory := _save_directory()
    var result := DirAccess.make_dir_recursive_absolute(directory)
    if result != OK:
        return
    var path := directory.path_join("partita.json")
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        return
    var data := {"version":8,"wood":wood,"coins":coins,"kills":kills,"weapon_level":weapon_level,"base_hp":base_hp,"stockade_built":stockade_built,"gate_broken":gate_broken,"elapsed":elapsed,"next_raid":next_raid,"raid_number":raid_number,"px":hero.global_position.x,"pz":hero.global_position.z,"hp":hero.hp}
    file.store_string(JSON.stringify(data,"  "))
    file.close()

func _load_progress() -> void:
    var path := _save_directory().path_join("partita.json")
    if not FileAccess.file_exists(path):
        return
    var file := FileAccess.open(path,FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version",0)) != 8:
        return
    wood = int(parsed.get("wood",0))
    coins = int(parsed.get("coins",0))
    kills = int(parsed.get("kills",0))
    weapon_level = int(parsed.get("weapon_level",1))
    base_hp = float(parsed.get("base_hp",150.0))
    elapsed = float(parsed.get("elapsed",0.0))
    next_raid = maxf(elapsed + 60.0,float(parsed.get("next_raid",FIRST_RAID_TIME)))
    raid_number = int(parsed.get("raid_number",0))
    hero.hp = float(parsed.get("hp",100.0))
    hero.global_position = Vector3(float(parsed.get("px",0.0)), .13, float(parsed.get("pz",7.0)))
    stockade_built = bool(parsed.get("stockade_built",false))
    gate_broken = bool(parsed.get("gate_broken",false))
    if stockade_built:
        _build_stockade()
    show_message("Partita recuperata dai salvataggi.", 3.0)

func _exit_tree() -> void:
    if hero != null:
        _save_progress()
