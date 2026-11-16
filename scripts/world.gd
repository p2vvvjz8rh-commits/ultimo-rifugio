extends Node3D
## ALFA 13 - paesaggio rifinito e missione radio opzionale.
## Asset e animazioni Quaternius glTF, senza conversione in sprite.

const FENCE_COST := 45
const REPAIR_COST := 18
const FIRST_RAID_TIME := 240.0
const WORLD_HALF := 22.0
const WALL_HP_MAX := 240.0
const GATE_HP_MAX := 280.0
const BENCH_REPAIR_COST := 8
const BENCH_REPAIR_AMOUNT := 100.0
const BENCH_HP_MAX := 130.0
const CABIN_HP_MAX := 150.0

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
var gate_barrier: CollisionShape3D
var manual_target: String = ""
var gate_right_collision: CollisionShape3D
var wall_segments: Array[Dictionary] = []
var gate_hp: float = GATE_HP_MAX
var gate_indicator: Label3D
var camera_distance: float = 1.0
var enemy_indicator_root: Control
var enemy_indicators: Array[Label] = []
var noise_spawn_cooldown: float = 0.0
var wall_warning_time: float = 0.0
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
var occluders: Array[MeshInstance3D] = []
var occlusion_targets: Dictionary = {}
var occlusion_alpha: Dictionary = {}
var occlusion_originals: Dictionary = {}
var occlusion_materials: Dictionary = {}
var occlusion_scan_timer: float = 0.0
var repair_bench: Node3D
var repair_bench_label: Label3D
var bench_hint_time: float = 0.0
var new_game_dialog: ConfirmationDialog
var skip_save_on_exit: bool = false
var supply_caches: Array[Dictionary] = []
var collected_supplies: int = 0
var supply_goal: int = 4
var supply_reward_available: bool = false
var next_cache_spawn: float = 0.0
var old_wall_scale: float = 1.0
var old_gate_scale: float = 1.0
var cabin_root: Node3D
var cabin_visual
var cabin_meshes: Array[MeshInstance3D] = []
var gate_visual
var bench_visual
var bench_hp: float = BENCH_HP_MAX
var repair_popup: PopupPanel
var test_panel: PanelContainer
var test_panel_visible: bool = false
var test_stats: Label
var radio_station

func _ready() -> void:
    rng.seed = 20261114
    _create_environment()
    _create_ground()
    _create_cabin()
    _create_forest()
    _decorate_world()
    _create_hero()
    _create_radio_station()
    _create_camera()
    _create_hud()
    _load_progress()
    _spawn_initial_enemies()
    _spawn_supply_cache()
    _spawn_supply_cache()
    _spawn_supply_cache()
    _sync_structure_visuals()
    show_message("ALFA 13: esplora a EST, trova la radio e premi R per una missione!", 6.0)

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
    _update_supply_caches(delta)
    _update_gate(delta)
    _update_camera(delta)
    _update_hud()
    _sync_structure_visuals()
    _update_occlusion(delta)
    bench_hint_time = maxf(0.0, bench_hint_time - delta)
    noise_spawn_cooldown = maxf(0.0, noise_spawn_cooldown - delta)
    wall_warning_time = maxf(0.0, wall_warning_time - delta)
    enemies = enemies.filter(func(enemy): return is_instance_valid(enemy))
    if save_time > 12.0:
        save_time = 0.0
        _save_progress()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                paused = not paused
                show_message("PAUSA" if paused else "Esplorazione ripresa",2.0)
            KEY_Q:
                if not paused: hero.special_attack()
            KEY_SPACE:
                if not paused: hero.dash()
            KEY_B:
                if not paused: _build_or_repair()
            KEY_E:
                if not paused: _use_repair_bench()
            KEY_U:
                if not paused: _upgrade_weapon()
            KEY_N:
                if not new_game_dialog.visible: _ask_new_game()
            KEY_T:
                if not paused: _test_start_raid()
            KEY_F3:
                _toggle_test_panel()
            KEY_R:
                if not paused and is_instance_valid(radio_station):
                    radio_station.activate()

func _unhandled_input(event: InputEvent) -> void:
    # I controlli da tastiera sono intercettati in _input anche dopo aver cliccato un pulsante UI.
    if event is InputEventMouseButton and event.pressed and not paused:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            _inspect_structure(event.position)
            get_viewport().set_input_as_handled()
            return
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_distance = maxf(0.62, camera_distance - 0.10)
            get_viewport().set_input_as_handled()
            return
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_distance = minf(1.75, camera_distance + 0.10)
            get_viewport().set_input_as_handled()
            return
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
    # Piano visivo piu ampio della zona giocabile: il confine non appare come un precipizio.
    _box(ground, "Prato", Vector3(0, -0.22, 0), Vector3(108, 0.4, 108), "#628657")
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
    cabin_root = base
    _box(base, "Fondamenta", Vector3(0, 0.14, 0), Vector3(4.8, .28, 4.8), "#676452")
    _box(base, "Pareti", Vector3(0, 1.28, 0), Vector3(3.75, 2.45, 3.75), "#a47d56")
    for z in [-1.90, 1.90]:
        _box(base, "Trave", Vector3(-1.74, 1.22, z), Vector3(.16, 2.4, .18), "#684833")
        _box(base, "Trave", Vector3(1.74, 1.22, z), Vector3(.16, 2.4, .18), "#684833")
    _box(base, "Tetto_sinistro", Vector3(-1.02, 2.79, 0.0), Vector3(2.55, .17, 4.5), "#425a65", -0.36)
    _box(base, "Tetto_destro", Vector3(1.02, 2.79, 0.0), Vector3(2.55, .17, 4.5), "#354c55", 0.36)
    # Bordature del tetto, travi del portico e dettagli della facciata.
    for side in [-1.0,1.0]:
        _box(base,"Fascia_sottotetto",Vector3(side*1.69,2.31,0.0),Vector3(.13,.18,4.72),"#6b5542")
        _box(base,"Trave_frontone",Vector3(side*1.02,2.67,2.28),Vector3(2.10,.12,.14),"#816347",side*-.36)
        _box(base,"Colonna_portico",Vector3(side*1.28,1.26,3.51),Vector3(.15,2.40,.16),"#71523b")
    _box(base,"Architrave_portico",Vector3(0,2.43,3.52),Vector3(2.88,.18,.19),"#785840")
    for n in range(4):
        _box(base,"Listello_facciata_%d" % n,Vector3(-1.42+float(n)*.95,.44,1.93),Vector3(.045,.68,.075),"#785a44")
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
    # Oggetti di scena per dare al rifugio un aspetto abitato.
    for i in range(3):
        _box(base,"Cassa_rifornimenti_%d" % i,Vector3(-2.8 + float(i%2)*0.8,.38,-.8+float(i/2)*.7),Vector3(.68,.72,.68),"#98734f")
    _box(base,"Baule_medico",Vector3(2.8,.36,.8),Vector3(1.0,.72,.72),"#7b8166")
    _box(base,"Etichetta_baule",Vector3(2.8,.76,1.17),Vector3(.42,.07,.03),"#d7ddd1")
    _cone(base,"Lanterna_palo",Vector3(-2.35,1.10,2.25),.07,2.0,"#574b39",.07)
    _box(base,"Lanterna",Vector3(-2.35,2.06,2.25),Vector3(.36,.46,.36),"#f4c76f")
    _box(base,"Lanterna_cappello",Vector3(-2.35,2.34,2.25),Vector3(.45,.12,.45),"#504638")
    var porch_light := OmniLight3D.new()
    porch_light.name = "Luce_lanterna_portico"
    porch_light.position = Vector3(-2.35,2.04,2.25)
    porch_light.light_color = Color("#f9c87f")
    porch_light.omni_range = 4.0
    porch_light.light_energy = .36
    base.add_child(porch_light)
    for i in range(3):
        _box(base,"Sacchi_scorte_%d" % i,Vector3(2.35+float(i%2)*.38,.22,-.55+float(i/2)*.52),Vector3(.52,.42,.35),"#938669")
    _register_occluders(base)
    for item in base.get_children():
        if item is MeshInstance3D and String(item.name) != "Fondamenta":
            cabin_meshes.append(item as MeshInstance3D)
    cabin_visual = _make_structure_visual(base,"cabin",CABIN_HP_MAX,Vector3(0.0,4.05,0.0))

func _decorate_world() -> void:
    # Rocce, ciuffi, terra smossa e tronchi statici: nessuna nuova meccanica.
    for i in range(76):
        var x: float = rng.randf_range(-48.0,48.0)
        var z: float = rng.randf_range(-48.0,48.0)
        if absf(x) < 8.0 and z > -11.0 and z < 8.0:
            continue
        if rng.randf() < .42:
            _rock(self,"Roccia_di_sfondo",Vector3(x,.12,z),Vector3(rng.randf_range(.22,.65),rng.randf_range(.2,.4),rng.randf_range(.22,.70)),"#858d7a")
        else:
            var t := _cone(self,"Macchia_bassa",Vector3(x,.15,z),rng.randf_range(.20,.43),rng.randf_range(.27,.50),"#4a7950")
            t.rotation.z = rng.randf_range(-.3,.3)
    for i in range(27):
        var x: float = rng.randf_range(-21.0,21.0)
        var z: float = rng.randf_range(-21.0,21.0)
        if absf(x) < 6.8 and z > -10.0 and z < 5.5:
            continue
        var patch := _box(self,"Terra_smotata",Vector3(x,-.005,z),Vector3(rng.randf_range(.9,2.5),.024,rng.randf_range(.7,1.8)),"#788360")
        patch.rotation.y = rng.randf_range(0,TAU)
    # Piccoli fiori e funghi segnalano gli angoli meno frequentati del bosco.
    for i in range(58):
        var p: Vector2 = Vector2(rng.randf_range(-21.0,21.0),rng.randf_range(-21.0,21.0))
        if (absf(p.x) < 6.0 and p.y > -8.5 and p.y < 5.0) or p.distance_to(Vector2(13.0,-10.0)) < 2.6:
            continue
        var flower := _cone(self,"Fiore_di_bosco",Vector3(p.x,.20,p.y),.11,.20,"#e1b78e" if i%3 == 0 else ("#c5c2dc" if i%3 == 1 else "#e7d2a2"))
        flower.rotation.z = rng.randf_range(-.22,.22)
    for i in range(8):
        var x: float = rng.randf_range(-18.0,18.0)
        var z: float = rng.randf_range(-18.0,18.0)
        if absf(x) < 7.5 and z > -10.0 and z < 7.0:
            continue
        var log_mesh := _cone(self,"Tronco_caduto",Vector3(x,.20,z),.22,1.7,"#78533b",.20)
        log_mesh.rotation.z = PI * 0.5
        log_mesh.rotation.y = rng.randf_range(0.0,TAU)

func _create_forest() -> void:
    # Alberi ravvicinati rigenerabili per testare la raccolta; altri intorno alla radura.
    var near_positions := [Vector2(-7.0, 3.6), Vector2(-8.2, 7.2), Vector2(7.4, 5.3), Vector2(9.0, .9), Vector2(-7.8, -5.9), Vector2(8.0, -7.6)]
    for p in near_positions:
        _create_tree(p.x, p.y, rng.randf_range(.88, 1.12), true)
    for i in range(70):
        var pos := Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
        if absf(pos.x) < 6.6 and pos.y > -9.0 and pos.y < 7.8:
            continue
        if pos.distance_to(Vector2(13.0,-10.0)) < 4.6:
            continue
        if pos.length() < 10.5 and rng.randf() < .75:
            continue
        _create_tree(pos.x, pos.y, rng.randf_range(.85, 1.5), true)
    for i in range(33):
        var x := rng.randf_range(-20,20)
        var z := rng.randf_range(-20,20)
        if absf(x) < 7 and absf(z + 2.0) < 9:
            continue
        if Vector2(x,z).distance_to(Vector2(13.0,-10.0)) < 3.5:
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
    var slash1 := _box(tree,"Taglio_1",Vector3(.20,.82,.03),Vector3(.13,.12,.38),"#392b20",-.37)
    var slash2 := _box(tree,"Taglio_2",Vector3(.21,.67,.03),Vector3(.18,.18,.41),"#4c301d",.32)
    slash1.visible = false
    slash2.visible = false
    var stump := _cone(self,"Ceppo",Vector3(x,.14,z),.30 * scale_factor,.3,"#9e784e", .30 * scale_factor)
    stump.visible = false
    trees.append({"node":tree,"stump":stump,"hp":3,"regrow_at":0.0,"harvestable":harvestable,"slash1":slash1,"slash2":slash2})
    _register_occluders(tree)

func _create_hero() -> void:
    hero = preload("res://scripts/survivor.gd").new()
    add_child(hero)
    hero.global_position = Vector3(0, 0.10, 7.0)
    hero.configure(self)

func _create_radio_station() -> void:
    radio_station = preload("res://scripts/radio_event.gd").new()
    add_child(radio_station)
    radio_station.configure(self)
    # Un sentiero di terra collega visivamente la radura alla nuova scoperta.
    for i in range(11):
        var k: float = float(i)/10.0
        var x: float = lerpf(5.8,13.0,k)
        var z: float = lerpf(4.9,-10.0,k)
        var step_mesh := _box(self,"Sentiero_verso_radio",Vector3(x,-.003,z),Vector3(1.45,.027,1.85),"#8b8466")
        step_mesh.rotation.y = .3

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.name = "Telecamera_inclinata"
    camera.current = true
    camera.fov = 47.0
    camera.position = hero.global_position + Vector3(0, 14.5, 16.5) * camera_distance
    add_child(camera)
    camera.look_at(hero.global_position + Vector3(0, 1.15, -1.9), Vector3.UP)

func _update_camera(delta: float) -> void:
    var desired: Vector3 = hero.global_position + Vector3(0, 14.5, 16.5) * camera_distance
    camera.global_position = camera.global_position.lerp(desired, clampf(delta * 3.0, 0.0, 1.0))
    camera.look_at(hero.global_position + Vector3(0, 1.15, -2.0), Vector3.UP)

func _spawn_initial_enemies() -> void:
    # Presenze vicine ma fuori dal cortile: visibili anche prima della prima orda.
    _spawn_enemy(Vector3(-7.1, .13, -7.1), "normal", false)
    _spawn_enemy(Vector3(7.0, .13, -5.5), "normal", false)
    _spawn_enemy(Vector3(0.5, .13, -11.0), "normal", false)
    _spawn_enemy(Vector3(10.0, .13, 9.0), "runner", false)

func _spawn_enemy(at: Vector3, variant: String, wave: bool) -> void:
    var mob = preload("res://scripts/zombie.gd").new()
    add_child(mob)
    mob.global_position = at
    mob.configure(self, variant, wave)
    enemies.append(mob)

func has_clear_path(from_point: Vector3, to_point: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(from_point+Vector3.UP*1.0,to_point+Vector3.UP*1.0,5)
    var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    return collision.is_empty()

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
        var tree_node: Node3D = t["node"]
        t["stump"].visible = true
        t["regrow_at"] = elapsed + rng.randf_range(32.0, 48.0)
        wood += 9
        _floating_tree_number(tree_pos, "+9 LEGNO", true)
        var fall := create_tween()
        fall.tween_property(tree_node,"rotation:z",1.20,0.46)
        fall.tween_callback(func(): tree_node.visible = false)
        show_message("+9 LEGNO", 1.2)
    else:
        var remaining: int = int(t["hp"])
        var first_cut: MeshInstance3D = t["slash1"]
        var second_cut: MeshInstance3D = t["slash2"]
        first_cut.visible = true
        second_cut.visible = remaining <= 1
        (t["node"] as Node3D).rotation.z = .10 if remaining <= 1 else .02
        _floating_tree_number(tree_pos, "%d/3" % remaining)

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
            (t["node"] as Node3D).rotation.z = 0.0
            (t["slash1"] as MeshInstance3D).visible = false
            (t["slash2"] as MeshInstance3D).visible = false
            t["stump"].visible = false

func make_noise(where: Vector3, duration: float) -> void:
    noise_position = where
    noise_time = duration
    # Un rumore puo' richiamare qualcuno dal bosco, con limite per evitare orde infinite.
    if elapsed < 8.0 or noise_spawn_cooldown > 0.0:
        return
    var roaming_count := 0
    for enemy in enemies:
        if is_instance_valid(enemy) and not enemy.defeated and not enemy.from_wave:
            roaming_count += 1
    if roaming_count >= 5:
        return
    noise_spawn_cooldown = 20.0
    var side: float = -1.0 if rng.randf() < 0.5 else 1.0
    var spawn_x: float = clampf(where.x + side * rng.randf_range(7.0, 10.0), -19.0, 19.0)
    var spawn_z: float = clampf(where.z + rng.randf_range(-7.0, 7.0), -19.0, 19.0)
    if absf(spawn_x) < 5.9 and spawn_z > -8.8 and spawn_z < 4.8:
        spawn_z = -10.0
    _spawn_enemy(Vector3(spawn_x,0.13,spawn_z), "normal", false)

func _start_raid() -> void:
    raid_number += 1
    var count: int = mini(9, 2 + raid_number * 2)
    for i in range(count):
        var a := float(i) * TAU / float(count) + rng.randf_range(-.15,.15)
        var radius := rng.randf_range(13.0, 17.0)
        var variant := "runner" if i % 4 == 0 and raid_number >= 2 else "normal"
        _spawn_enemy(Vector3(cos(a) * radius, .13, sin(a) * radius), variant, true)
    if raid_number >= 4:
        _spawn_enemy(Vector3(15.5, .13, 2.0), "brute", true)
    next_raid = elapsed + maxf(250.0, 340.0 - float(raid_number) * 9.0)
    wood += 8
    coins += 5
    show_message("ORDA %d - +8 LEGNO E +5 MONETE PER PREPARARTI!" % raid_number, 5.0)

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
    elif _has_damaged_defenses():
        if wood < REPAIR_COST:
            show_message("Servono %d legno per la riparazione." % REPAIR_COST, 2.0)
            return
        wood -= REPAIR_COST
        gate_hp = GATE_HP_MAX
        gate_broken = false
        base_hp = CABIN_HP_MAX
        bench_hp = BENCH_HP_MAX
        for section in wall_segments:
            section["hp"] = WALL_HP_MAX
            for mesh in section["visuals"]:
                if is_instance_valid(mesh):
                    mesh.visible = true
            var collider: CollisionShape3D = section["collider"]
            collider.set_deferred("disabled", false)
            var indicator: Label3D = section["indicator"]
            indicator.visible = false
            var crack: MeshInstance3D = section["crack"]
            crack.visible = false
        if is_instance_valid(gate_indicator):
            gate_indicator.visible = false
        _sync_gate_collision(false)
        _sync_structure_visuals()
        show_message("Rifugio e difese riparati, banco compreso.", 2.3)
    else:
        show_message("Palizzata già integra.", 1.7)
    _save_progress()

func _damaged_wall_count() -> int:
    var count: int = 0
    for wall in wall_segments:
        if float(wall["hp"]) < WALL_HP_MAX:
            count += 1
    return count

func _make_structure_visual(parent: Node3D, kind: String, maximum: float, local_position: Vector3):
    # Nuove strutture potranno usare lo stesso componente senza modificare l'interfaccia.
    var component = preload("res://scripts/structure_visual.gd").new()
    component.name = "Stato_struttura_" + kind
    parent.add_child(component)
    component.configure(kind,maximum,local_position)
    return component

func _sync_structure_visuals() -> void:
    if is_instance_valid(cabin_visual):
        cabin_visual.set_health(base_hp)
        for item in cabin_meshes:
            if is_instance_valid(item):
                var title: String = String(item.name)
                var missing_roof: bool = base_hp > 0.0 and base_hp < CABIN_HP_MAX*.5 and title == "Tetto_sinistro"
                item.visible = title == "Fondamenta" or (base_hp > 0.0 and not missing_roof)
    if is_instance_valid(gate_visual):
        gate_visual.set_health(gate_hp)
        if is_instance_valid(gate_left) and is_instance_valid(gate_right):
            gate_left.visible = gate_hp > 0.0
            gate_right.visible = gate_hp > 0.0
            gate_left.rotation.z = .18 if gate_hp > 0.0 and gate_hp < GATE_HP_MAX*.5 else 0.0
            gate_right.rotation.z = -.12 if gate_hp > 0.0 and gate_hp < GATE_HP_MAX*.5 else 0.0
    if is_instance_valid(bench_visual):
        bench_visual.set_health(bench_hp)
    if is_instance_valid(repair_bench):
        var idx: int = 0
        for child in repair_bench.get_children():
            if child is MeshInstance3D:
                child.visible = bench_hp > 0.0 and not (bench_hp < BENCH_HP_MAX*.5 and idx == 2)
                idx += 1
    for wall in wall_segments:
        var hp_now: float = float(wall["hp"])
        var component = wall["durability"]
        if is_instance_valid(component):
            component.set_health(hp_now)
        var old: Label3D = wall["indicator"]
        old.visible = false
        var crack: MeshInstance3D = wall["crack"]
        crack.visible = false
        var meshes: Array = wall["visuals"]
        for i in range(meshes.size()):
            var mesh: MeshInstance3D = meshes[i]
            if is_instance_valid(mesh):
                mesh.visible = hp_now > 0.0 and not (hp_now < WALL_HP_MAX*.5 and i % 5 == 0)
        var collision: CollisionShape3D = wall["collider"]
        if hp_now <= 0.0 and not collision.disabled:
            collision.set_deferred("disabled",true)
        elif hp_now > 0.0 and collision.disabled:
            collision.set_deferred("disabled",false)
    if is_instance_valid(gate_indicator):
        gate_indicator.visible = false

func _create_test_panel(root: Control) -> void:
    test_panel = PanelContainer.new()
    test_panel.name = "Controlli_test"
    test_panel.anchor_left = 1.0
    test_panel.anchor_right = 1.0
    test_panel.offset_left = -250
    test_panel.offset_right = -16
    test_panel.offset_top = 132
    test_panel.offset_bottom = 610
    test_panel.add_theme_stylebox_override("panel",_make_panel_style())
    test_panel.visible = false
    root.add_child(test_panel)
    var column := VBoxContainer.new()
    test_panel.add_child(column)
    _label(column,"MODALITA DI PROVA (F3)",14,Color("#e6bb77"))
    var wave := _button(column,"AVVIA ORDA (T)")
    wave.pressed.connect(_test_start_raid)
    var healing := _button(column,"CURA PROTAGONISTA")
    healing.pressed.connect(_test_heal_hero)
    var add_wood := _button(column,"+50 LEGNO")
    add_wood.pressed.connect(_test_add_wood)
    var add_coins := _button(column,"+50 MONETE")
    add_coins.pressed.connect(_test_add_coins)
    var simulate := _button(column,"SIMULA DANNI")
    simulate.pressed.connect(_test_damage_all)
    var restore := _button(column,"RIPARA TUTTO (TEST)")
    restore.pressed.connect(_test_repair_all)
    test_stats = _label(column,"",12,Color("#e1e0bf"))

func _test_heal_hero() -> void:
    hero.hp = 100.0
    hero._update_health_bar()
    show_message("Salute protagonista ripristinata.",1.4)

func _test_add_wood() -> void:
    wood += 50
    _update_hud()
    show_message("+50 legno per i test.",1.4)

func _test_add_coins() -> void:
    coins += 50
    _update_hud()
    show_message("+50 monete per i test.",1.4)

func _toggle_test_panel() -> void:
    if not is_instance_valid(test_panel):
        return
    test_panel_visible = not test_panel_visible
    test_panel.visible = test_panel_visible

func _test_start_raid() -> void:
    if paused:
        return
    _start_raid()
    show_message("ORDA DI PROVA %d IN ARRIVO" % raid_number,3.0)

func _test_damage_all() -> void:
    if not stockade_built:
        show_message("Costruisci prima il recinto con B.",2.0)
        return
    for wall in wall_segments:
        wall["hp"] = maxf(0.0,float(wall["hp"])-WALL_HP_MAX*.34)
    gate_hp = maxf(0.0,gate_hp-GATE_HP_MAX*.34)
    gate_broken = gate_hp <= 0.0
    base_hp = maxf(0.0,base_hp-CABIN_HP_MAX*.34)
    bench_hp = maxf(0.0,bench_hp-BENCH_HP_MAX*.34)
    _sync_structure_visuals()
    _sync_gate_collision(gate_broken or current_gate_open > .03)
    show_message("Danni simulati: controlla barre e modelli.",2.6)
    _save_progress()

func _test_repair_all() -> void:
    for wall in wall_segments:
        wall["hp"] = WALL_HP_MAX
    gate_hp = GATE_HP_MAX
    gate_broken = false
    base_hp = CABIN_HP_MAX
    bench_hp = BENCH_HP_MAX
    _sync_structure_visuals()
    _sync_gate_collision(current_gate_open > .03)
    show_message("Strutture ripristinate, compreso il banco.",2.4)
    _save_progress()

func _create_repair_bench() -> void:
    if repair_bench != null and is_instance_valid(repair_bench):
        repair_bench.queue_free()
    repair_bench = Node3D.new()
    repair_bench.name = "Banco_di_riparazione"
    repair_bench.position = Vector3(-2.75,0.0,2.25)
    add_child(repair_bench)
    _box(repair_bench,"Banco_piano",Vector3(0.0,1.02,0.0),Vector3(1.8,.16,.92),"#946840")
    for x in [-.73,.73]:
        for z in [-.32,.32]:
            _box(repair_bench,"Banco_gamba",Vector3(x,.50,z),Vector3(.17,1.0,.17),"#65462c")
    _box(repair_bench,"Cassetta_attrezzi",Vector3(-.48,1.23,0.0),Vector3(.55,.25,.42),"#54676a")
    _box(repair_bench,"Martello_impugnatura",Vector3(.31,1.2,0.0),Vector3(.10,.13,.55),"#7f5940")
    _box(repair_bench,"Martello_testa",Vector3(.31,1.3,-.22),Vector3(.36,.15,.16),"#909593")
    repair_bench_label = Label3D.new()
    repair_bench_label.name = "Istruzione_riparazione"
    repair_bench_label.position = Vector3(0.0,1.95,0.0)
    repair_bench_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    repair_bench_label.no_depth_test = true
    repair_bench_label.font_size = 30
    repair_bench_label.pixel_size = .007
    repair_bench_label.outline_size = 6
    repair_bench_label.text = "BANCO RIPARAZIONI"
    repair_bench.add_child(repair_bench_label)
    _register_occluders(repair_bench)
    bench_visual = _make_structure_visual(repair_bench,"bench",BENCH_HP_MAX,Vector3(0.0,2.18,0.0))

func _use_repair_bench() -> void:
    if not stockade_built or repair_bench == null or not is_instance_valid(repair_bench):
        show_message("Costruisci prima la palizzata.",1.8)
        return
    if bench_hp <= 0.0:
        show_message("Banco distrutto: ripristinalo con B.",2.5)
        return
    if hero.global_position.distance_to(repair_bench.global_position) > 4.4:
        show_message("Avvicinati al banco nel cortile, poi premi E.",2.0)
        return
    manual_target = ""
    _refresh_repair_menu()
    repair_popup.popup_centered()

func _refresh_repair_menu() -> void:
    if repair_popup == null:
        return
    var body: VBoxContainer = repair_popup.get_node("Menu") as VBoxContainer
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()
    var header := Label.new()
    header.text = "RIPARAZIONI  -  LEGNO DISPONIBILE: %d" % wood
    body.add_child(header)
    var descriptions: Array[Dictionary] = [
        {"type":"wall","label":"Sezione di palizzata piu danneggiata","cost":BENCH_REPAIR_COST,"missing":_max_wall_damage()},
        {"type":"gate","label":"Cancello","cost":BENCH_REPAIR_COST,"missing":GATE_HP_MAX-gate_hp},
        {"type":"cabin","label":"Rifugio","cost":12,"missing":CABIN_HP_MAX-base_hp},
        {"type":"bench","label":"Banco di riparazione","cost":8,"missing":BENCH_HP_MAX-bench_hp}
    ]
    for item in descriptions:
        var option := Button.new()
        option.text = "%s  |  %d legno  |  Danni: %d HP" % [str(item["label"]),int(item["cost"]),ceili(float(item["missing"]))]
        option.disabled = float(item["missing"]) <= 0.0 or wood < int(item["cost"])
        var selected: String = str(item["type"])
        option.pressed.connect(func(): _repair_selected(selected))
        body.add_child(option)
    var all_option := Button.new()
    all_option.text = "Ripara tutto completamente | %d legno" % REPAIR_COST
    all_option.disabled = not _has_damaged_defenses() or wood < REPAIR_COST
    all_option.pressed.connect(_repair_all_at_bench)
    body.add_child(all_option)
    var close := Button.new()
    close.text = "Chiudi"
    close.pressed.connect(func(): repair_popup.hide())
    body.add_child(close)

func _max_wall_damage() -> float:
    var lost: float = 0.0
    for section in wall_segments:
        lost = maxf(lost,WALL_HP_MAX-float(section["hp"]))
    return lost

func _repair_selected(kind: String) -> void:
    var cost: int = 12 if kind == "cabin" else BENCH_REPAIR_COST
    var manual: bool = manual_target != ""
    var location: Vector3 = _manual_position(kind) if manual else repair_bench.global_position
    if paused or wood < cost or hero.global_position.distance_to(location) > 4.4 or (manual and kind != manual_target) or (not manual and bench_hp <= 0.0):
        repair_popup.hide()
        return
    var applied: float = 0.0
    var repaired_name: String = ""
    var feedback_position: Vector3 = _structure_position(kind)
    if kind.begins_with("wall:"):
        var index: int = int(kind.get_slice(":",1))
        if index < 0 or index >= wall_segments.size():
            return
        var section: Dictionary = wall_segments[index]
        applied = minf(WALL_HP_MAX-float(section["hp"]),BENCH_REPAIR_AMOUNT)
        section["hp"] = float(section["hp"]) + applied
        repaired_name = str(section["name"])
        feedback_position = section["position"] + Vector3.UP
    match kind:
        "wall":
            var target: Dictionary = {}
            var damage: float = 0.0
            for section in wall_segments:
                var missing: float = WALL_HP_MAX - float(section["hp"])
                if missing > damage:
                    damage = missing
                    target = section
            if damage > 0.0:
                applied = minf(damage,BENCH_REPAIR_AMOUNT)
                target["hp"] = minf(WALL_HP_MAX,float(target["hp"])+applied)
                repaired_name = str(target["name"])
                feedback_position = target["position"] + Vector3.UP * 1.7
                var col: CollisionShape3D = target["collider"]
                col.set_deferred("disabled",false)
        "gate":
            applied = minf(GATE_HP_MAX-gate_hp,BENCH_REPAIR_AMOUNT)
            gate_hp += applied
            gate_broken = gate_hp <= 0.0
            repaired_name = "Cancello"
            _sync_gate_collision(current_gate_open > .03)
        "cabin":
            applied = minf(CABIN_HP_MAX-base_hp,75.0)
            base_hp += applied
            repaired_name = "Rifugio"
        "bench":
            applied = minf(BENCH_HP_MAX-bench_hp,65.0)
            bench_hp += applied
            repaired_name = "Banco di riparazione"
    if applied > 0.0:
        wood -= cost
        _sync_structure_visuals()
        _floating_tree_number(feedback_position,"+%d HP" % ceili(applied),true)
        show_message("%s riparato: +%d HP" % [repaired_name,ceili(applied)],2.3)
        _save_progress()
    repair_popup.hide()

func _structure_position(kind: String) -> Vector3:
    match kind:
        "wall":
            var most: float = -1.0
            var place: Vector3 = Vector3(0.0,1.7,-7.9)
            for section in wall_segments:
                var damage: float = WALL_HP_MAX - float(section["hp"])
                if damage > most:
                    most = damage
                    place = section["position"] + Vector3.UP * 1.7
            return place
        "gate":
            return Vector3(0.0,2.0,4.0)
        "bench":
            return repair_bench.global_position + Vector3.UP * 1.5
    return Vector3(0.0,3.0,-3.6)

func _build_stockade() -> void:
    if fence_root != null and is_instance_valid(fence_root):
        fence_root.queue_free()
    if repair_bench != null and is_instance_valid(repair_bench):
        repair_bench.queue_free()
    wall_segments.clear()
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
        if absf(x) > 1.55:
            _post(fence_root, Vector3(x,0,front_z))
    for i in range(23):
        var z := back_z + float(i)*(front_z-back_z)/22.0
        _post(fence_root, Vector3(left_x,0,z))
        _post(fence_root, Vector3(right_x,0,z))
    # Rinforzi suddivisi per sezione: una breccia non lascia travi sospese.
    _box(fence_root,"Montante_cancello_SX",Vector3(-1.52,1.26,4),Vector3(.32,2.6,.38),"#6c482d")
    _box(fence_root,"Montante_cancello_DX",Vector3(1.52,1.26,4),Vector3(.32,2.6,.38),"#6c482d")
    gate_left = Node3D.new()
    gate_left.name = "Anta_SX"
    gate_left.position = Vector3(-1.44, 0.0, 4.0)
    fence_root.add_child(gate_left)
    _box(gate_left,"Legno_anta",Vector3(.72,1.03,0),Vector3(1.44,2.08,.22),"#997048")
    _box(gate_left,"Rinforzo",Vector3(.72,.75,.15),Vector3(1.44,.16,.12),"#533b29")
    gate_right = Node3D.new()
    gate_right.name = "Anta_DX"
    gate_right.position = Vector3(1.44, 0.0, 4.0)
    fence_root.add_child(gate_right)
    _box(gate_right,"Legno_anta",Vector3(-.72,1.03,0),Vector3(1.44,2.08,.22),"#997048")
    _box(gate_right,"Rinforzo",Vector3(-.72,.75,.15),Vector3(1.44,.16,.12),"#533b29")
    for x in [-5.3, 5.3]:
        for z in [back_z, front_z]:
            _cone(fence_root,"Palo_angolare",Vector3(x,1.75,z),.37,3.5,"#7f5838",.17)
    # Ogni tratto ha collisione e HP indipendenti (nessun HP condiviso col rifugio).
    for i in range(3):
        var x_center: float = -3.55 + float(i) * 3.55
        _wall_collision("Parete_nord_%d" % (i+1),Vector3(x_center,1.12,back_z),Vector3(3.55,2.24,.50))
    for i in range(2):
        var z_center: float = -4.925 + float(i) * 5.95
        _wall_collision("Parete_ovest_%d" % (i+1),Vector3(left_x,1.12,z_center),Vector3(.50,2.24,5.95))
        _wall_collision("Parete_est_%d" % (i+1),Vector3(right_x,1.12,z_center),Vector3(.50,2.24,5.95))
    _wall_collision("Parete_frontale_sinistra", Vector3(-3.4,1.12,front_z), Vector3(3.8,2.24,.50))
    _wall_collision("Parete_frontale_destra", Vector3(3.4,1.12,front_z), Vector3(3.8,2.24,.50))
    # Anche le ante hanno collider, legati allo stesso nodo che ruota.
    var barrier_body := StaticBody3D.new()
    barrier_body.collision_layer = 4 # Blocco fisso riservato agli zombie.
    barrier_body.collision_mask = 0
    fence_root.add_child(barrier_body)
    gate_barrier = CollisionShape3D.new()
    var barrier_shape := BoxShape3D.new()
    barrier_shape.size = Vector3(2.88,2.6,.3)
    gate_barrier.shape = barrier_shape
    gate_barrier.position = Vector3(0,1.3,4)
    barrier_body.add_child(gate_barrier)
    gate_left_collision = _gate_collision(gate_left, "Collider_anta_sinistra", Vector3(.72,1.03,0.0))
    gate_right_collision = _gate_collision(gate_right, "Collider_anta_destra", Vector3(-.72,1.03,0.0))
    gate_indicator = _create_defense_indicator(fence_root,Vector3(0.0,3.0,4.0))
    _sync_gate_collision(false)
    gate_visual = _make_structure_visual(fence_root,"gate",GATE_HP_MAX,Vector3(0.0,3.0,4.0))
    _create_repair_bench()
    _register_occluders(fence_root)

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
    var indicator := _create_defense_indicator(body, center + Vector3(0.0, 1.65, 0.0))
    var durability = _make_structure_visual(body,"wall",WALL_HP_MAX,center + Vector3(0.0,1.65,0.0))
    var visuals: Array[MeshInstance3D] = []
    var rail := _box(fence_root,"Trave_della_sezione_" + title,Vector3(center.x,1.06,center.z),Vector3(size.x,.24,size.z),"#674a32")
    for obj in fence_root.get_children():
        if obj is MeshInstance3D and (obj.name.begins_with("Asse") or obj.name.begins_with("Punta")):
            if absf(obj.position.x - center.x) <= size.x * 0.45 and absf(obj.position.z - center.z) <= size.z * 0.45:
                visuals.append(obj)
    visuals.append(rail)
    # Segno di danno visivo localizzato: compare quando la sezione perde meta salute.
    var crack := _box(fence_root,"Asse_scheggiata_" + title,Vector3(center.x,1.35,center.z + size.z*.5 + .035),Vector3(minf(size.x*.65,1.15),.11,.09),"#4a3123",-.34)
    if size.x < size.z:
        crack.position = Vector3(center.x + size.x*.5 + .035,1.35,center.z)
        crack.rotation.z = 0.0
        crack.rotation.y = .35
        var damage_box: BoxMesh = crack.mesh as BoxMesh
        damage_box.size = Vector3(.09,.11,minf(size.z*.65,1.15))
    crack.visible = false
    wall_segments.append({"name":title, "hp":WALL_HP_MAX, "position":Vector3(center.x,0.0,center.z), "collider":collider,"indicator":indicator,"visuals":visuals,"crack":crack,"durability":durability})

func _create_defense_indicator(parent: Node3D, position_3d: Vector3) -> Label3D:
    var indicator := Label3D.new()
    indicator.name = "Salute_difesa"
    indicator.position = position_3d
    indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    indicator.no_depth_test = true
    indicator.font_size = 35
    indicator.pixel_size = 0.009
    indicator.outline_size = 7
    indicator.modulate = Color("#ffb577")
    indicator.outline_modulate = Color("#301910")
    indicator.visible = false
    parent.add_child(indicator)
    return indicator

func _has_damaged_defenses() -> bool:
    if gate_broken or gate_hp < GATE_HP_MAX or base_hp < CABIN_HP_MAX or bench_hp < BENCH_HP_MAX:
        return true
    for section in wall_segments:
        if float(section["hp"]) < WALL_HP_MAX:
            return true
    return false

func _nearest_wall_section(from_position: Vector3) -> int:
    var selected := -1
    var best := INF
    for i in range(wall_segments.size()):
        var section: Dictionary = wall_segments[i]
        if float(section["hp"]) <= 0.0:
            continue
        var point: Vector3 = section["position"]
        # Distanza al segmento rettangolare, non al suo centro.
        var collider: CollisionShape3D = section["collider"]
        var dimensions: Vector3 = (collider.shape as BoxShape3D).size
        var dx: float = maxf(absf(from_position.x - point.x) - dimensions.x * 0.5, 0.0)
        var dz: float = maxf(absf(from_position.z - point.z) - dimensions.z * 0.5, 0.0)
        var score: float = dx * dx + dz * dz
        if score < best:
            best = score
            selected = i
    return selected

func defense_target(from_position: Vector3) -> Vector3:
    if not stockade_built:
        return Vector3(0.0,0.0,-3.6)
    if absf(from_position.x) < 4.75 and from_position.z > -7.45 and from_position.z < 3.45:
        return Vector3(0.0,0.0,-3.6)
    if from_position.z > 3.45 and absf(from_position.x) < 1.35:
        return Vector3(0.0,0.0,5.05) if not gate_broken else Vector3(0.0,0.0,2.5)
    # Una breccia permette il passaggio, ma solo in quel tratto.
    var breach_distance: float = 7.0
    var breach_target: Vector3 = Vector3.ZERO
    var found_breach: bool = false
    for wall in wall_segments:
        if float(wall["hp"]) > 0.0:
            continue
        var breach: Vector3 = wall["position"]
        var dist: float = from_position.distance_to(breach)
        if dist < breach_distance:
            breach_distance = dist
            breach_target = breach
            if absf(breach.x) > 4.8:
                breach_target.x += -1.4 if breach.x > 0.0 else 1.4
            elif breach.z > 2.0:
                breach_target.z -= 1.4
            else:
                breach_target.z += 1.4
            found_breach = true
    if found_breach:
        return breach_target
    var index := _nearest_wall_section(from_position)
    if index == -1:
        return Vector3(0.0,0.0,-3.6)
    var section: Dictionary = wall_segments[index]
    var center: Vector3 = section["position"]
    var collider: CollisionShape3D = section["collider"]
    var dims: Vector3 = (collider.shape as BoxShape3D).size
    var attack_point := center
    if dims.x > dims.z:
        attack_point.x = clampf(from_position.x,center.x-dims.x*0.5+0.35,center.x+dims.x*0.5-0.35)
        attack_point.z = center.z + (1.05 if from_position.z >= center.z else -1.05)
    else:
        attack_point.z = clampf(from_position.z,center.z-dims.z*0.5+0.35,center.z+dims.z*0.5-0.35)
        attack_point.x = center.x + (1.05 if from_position.x >= center.x else -1.05)
    return attack_point

func attack_defense_at(from_position: Vector3, damage: float) -> void:
    if absf(from_position.x) < 4.75 and from_position.z > -7.45 and from_position.z < 3.45:
        if is_instance_valid(repair_bench) and from_position.distance_to(repair_bench.global_position) < 2.2 and bench_hp > 0.0:
            bench_hp = maxf(0.0,bench_hp-damage*.36)
            if bench_hp <= 0.0:
                show_message("BANCO DISTRUTTO! Ripristinalo con B.",3.0)
            _sync_structure_visuals()
        else:
            damage_base(damage)
        return
    if from_position.z > 4.0 and absf(from_position.x) < 1.35 and not gate_broken:
        gate_hp = maxf(0.0,gate_hp-damage * .36)
        if gate_hp <= 0.0:
            gate_broken = true
            _sync_gate_collision(true)
            show_message("CANCELLO DISTRUTTO! Ripara con B.",3.0)
        return
    var index := _nearest_wall_section(from_position)
    if index == -1 or not stockade_built:
        damage_base(damage)
        return
    var section: Dictionary = wall_segments[index]
    if float(section["hp"]) <= 0.0:
        return
    section["hp"] = maxf(0.0, float(section["hp"]) - damage * .36)
    var hp: float = float(section["hp"])
    _sync_structure_visuals()
    if hp <= 0.0:
        var collider: CollisionShape3D = section["collider"]
        collider.set_deferred("disabled", true)
        for mesh in section["visuals"]:
            if is_instance_valid(mesh):
                mesh.visible = false
        show_message("BRECCIA NELLA PALIZZATA! Ripara con B.",3.0)
    elif hp < WALL_HP_MAX * 0.5 and wall_warning_time <= 0.0:
        wall_warning_time = 6.0
        show_message("MURO DANNEGGIATO: %s" % str(section["name"]),2.8)

func _gate_collision(leaf: Node3D, title: String, offset: Vector3) -> CollisionShape3D:
    var body := StaticBody3D.new()
    body.name = title
    body.collision_layer = 1
    body.collision_mask = 0
    body.add_to_group("palizzata_solida")
    leaf.add_child(body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.44,2.07,.23)
    collider.shape = shape
    collider.position = offset
    body.add_child(collider)
    return collider

func _sync_gate_collision(is_open: bool) -> void:
    if is_instance_valid(gate_barrier):
        gate_barrier.set_deferred("disabled", gate_broken or gate_hp <= 0.0)
    # Le ante animate bloccano il protagonista solo da chiuse.
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
    var open_target := 1.0 if hero.global_position.distance_to(Vector3(0,0,4.1)) < 4.6 else 0.0
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
    # La casetta ha HP separati e viene colpita solo se lo zombie la raggiunge.
    if base_hp <= 0.0:
        return
    base_hp = maxf(0.0, base_hp - damage)
    _sync_structure_visuals()
    if base_hp <= 0.0:
        wood = maxi(0, wood - 10)
        show_message("RIFUGIO CROLLATO! Riparalo con B.", 3.0)
    elif base_hp < CABIN_HP_MAX*.5 and wall_warning_time <= 0.0:
        wall_warning_time = 6.0
        show_message("Rifugio in pericolo! Serve una riparazione.",2.4)

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
    left.custom_minimum_size = Vector2(250,152)
    left.add_theme_stylebox_override("panel",_make_panel_style())
    root.add_child(left)
    var left_vbox := VBoxContainer.new()
    left.add_child(left_vbox)
    _label(left_vbox,"ULTIMO RIFUGIO · ALFA 13",13,Color("#e6bb77"))
    var start_over := Button.new()
    start_over.text = "NUOVA PARTITA"
    start_over.custom_minimum_size = Vector2(150,28)
    start_over.pressed.connect(_ask_new_game)
    left_vbox.add_child(start_over)
    new_game_dialog = ConfirmationDialog.new()
    new_game_dialog.title = "Inizia una nuova partita?"
    new_game_dialog.dialog_text = "La partita attuale verra conservata come backup. Vuoi ricominciare da zero?"
    new_game_dialog.ok_button_text = "Nuova partita"
    new_game_dialog.confirmed.connect(_start_new_game)
    root.add_child(new_game_dialog)
    repair_popup = PopupPanel.new()
    repair_popup.name = "Menu_riparazioni"
    repair_popup.size = Vector2i(440,310)
    root.add_child(repair_popup)
    var repair_list := VBoxContainer.new()
    repair_list.name = "Menu"
    repair_list.custom_minimum_size = Vector2(420,270)
    repair_popup.add_child(repair_list)
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
    _create_test_panel(root)
    var guide := _label(root,"WASD / frecce o mouse premuto: muovi   •   Zombie: attacco automatico   •   Alberi: raccolta automatica   •   E: banco   •   Clic destro: ispeziona/ripara   •   R: radio   •   N: nuova partita   •   ESC: pausa",12,Color("#f0e3bb"))
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
    top_hud.text = "LEGNO %d    MONETE %d   |   ZOOM: %d%%" % [wood,coins,roundi(100.0/camera_distance)]
    info_hud.text = "RIFUGIO: %d/150   |   ARMA Lv.%d   |   UCCISIONI %d" % [ceili(base_hp),weapon_level,kills]
    var remain := maxi(0, ceili(next_raid - elapsed))
    objective_hud.text = "SCORTE %d/%d  |  ORDA %d:%02d" % [collected_supplies,supply_goal,int(remain / 60),remain % 60]
    if is_instance_valid(radio_station) and radio_station.active:
        objective_hud.text = "DIFENDI LA RADIO: %ds  |  ORDA %d:%02d" % [ceili(radio_station.remaining),int(remain / 60),remain % 60]
    if not stockade_built:
        build_button.text = "RECINTO · %d LEGNO" % FENCE_COST
        build_button.disabled = wood < FENCE_COST
    else:
        build_button.text = "RIPARA · %d LEGNO" % REPAIR_COST if _has_damaged_defenses() else "RECINTO COMPLETO"
        build_button.disabled = (wood < REPAIR_COST) or not _has_damaged_defenses()
    var cost := 12 + (weapon_level - 1) * 14
    upgrade_button.text = "ARMA Lv.%d · %d MON." % [weapon_level,cost] if weapon_level < 4 else "ARMA MASSIMA"
    upgrade_button.disabled = coins < cost or weapon_level >= 4
    special_button.disabled = hero.special_cooldown > 0.0
    dodge_button.disabled = hero.dash_cooldown > 0.0
    if is_instance_valid(test_stats):
        test_stats.text = "Rifugio %d  |  Banco %d  |  Mura da riparare %d" % [ceili(base_hp),ceili(bench_hp),_damaged_wall_count()]
    if is_instance_valid(repair_bench_label):
        var close_to_bench: bool = hero.global_position.distance_to(repair_bench.global_position) < 4.4
        if bench_hp <= 0.0:
            repair_bench_label.text = "BANCO DISTRUTTO (B)"
        else:
            repair_bench_label.text = "PREMI E - RIPARAZIONI" if close_to_bench else "BANCO RIPARAZIONI"

func _register_occluders(node: Node) -> void:
    # Ogni mesh e indipendente: il tetto puo svanire senza cancellare la casa.
    if node is MeshInstance3D:
        var mesh: MeshInstance3D = node as MeshInstance3D
        if mesh.mesh != null and mesh.material_override is StandardMaterial3D:
            occluders.append(mesh)
    for child in node.get_children():
        _register_occluders(child)

func _update_occlusion(delta: float) -> void:
    # Scansiona a intervalli per non ripetere ogni controllo a ogni frame.
    occlusion_scan_timer -= delta
    if occlusion_scan_timer <= 0.0:
        occlusion_scan_timer = 0.14
        occlusion_targets.clear()
        var characters: Array[Vector3] = [hero.global_position + Vector3.UP * 1.15]
        for enemy in enemies:
            if is_instance_valid(enemy) and not enemy.defeated:
                if characters.size() >= 19:
                    break
                characters.append(enemy.global_position + Vector3.UP * 1.1)
        var eye: Vector3 = camera.global_position
        for mesh in occluders:
            if not is_instance_valid(mesh) or not mesh.visible:
                continue
            var local_eye: Vector3 = mesh.global_transform.affine_inverse() * eye
            var bounds: AABB = mesh.get_aabb()
            var id: int = mesh.get_instance_id()
            for point in characters:
                if camera.is_position_behind(point):
                    continue
                var local_target: Vector3 = mesh.global_transform.affine_inverse() * point
                var direction: Vector3 = local_target - local_eye
                # Evita di sbiadire la mesh sulla quale si trova il bersaglio.
                if direction.length_squared() < .04:
                    continue
                if bounds.intersects_segment(local_eye,local_target) != null:
                    occlusion_targets[id] = true
                    break
    # La transizione resta fluida anche tra due scansioni.
    for mesh in occluders:
        if not is_instance_valid(mesh):
            continue
        var id: int = mesh.get_instance_id()
        var desired: float = .24 if occlusion_targets.has(id) else 1.0
        var previous: float = float(occlusion_alpha.get(id,1.0))
        var current: float = move_toward(previous,desired,delta * 3.6)
        if current >= .999:
            if occlusion_originals.has(id):
                mesh.material_override = occlusion_originals[id]
                occlusion_originals.erase(id)
                occlusion_materials.erase(id)
            occlusion_alpha.erase(id)
        else:
            if not occlusion_materials.has(id):
                var source: StandardMaterial3D = mesh.material_override as StandardMaterial3D
                if source == null:
                    continue
                occlusion_originals[id] = source
                var transparent: StandardMaterial3D = source.duplicate() as StandardMaterial3D
                transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                mesh.material_override = transparent
                occlusion_materials[id] = transparent
            var material: StandardMaterial3D = occlusion_materials[id]
            var tint: Color = material.albedo_color
            tint.a = current
            material.albedo_color = tint
            occlusion_alpha[id] = current

func show_message(message: String, duration: float = 2.5) -> void:
    if notify_hud == null:
        return
    notify_hud.text = message
    message_time = duration

func _ask_new_game() -> void:
    if is_instance_valid(new_game_dialog):
        new_game_dialog.popup_centered()

func _start_new_game() -> void:
    var current: String = _save_directory().path_join("partita.json")
    if FileAccess.file_exists(current):
        var backup: String = _save_directory().path_join("partita_backup_%s.json" % Time.get_datetime_string_from_system().replace(":","-"))
        var status: int = DirAccess.rename_absolute(current,backup)
        if status != OK:
            show_message("Impossibile creare backup della partita. Operazione annullata.",3.0)
            return
    skip_save_on_exit = true
    get_tree().reload_current_scene()

func _spawn_supply_cache() -> void:
    if supply_caches.size() >= 5:
        return
    var place: Vector3 = Vector3.ZERO
    for attempt in range(30):
        place = Vector3(rng.randf_range(-18.0,18.0),0.0,rng.randf_range(-18.0,18.0))
        if place.distance_to(hero.global_position) < 6.0:
            continue
        if absf(place.x) < 6.0 and place.z > -9.0 and place.z < 6.0:
            continue
        break
    var cache := Node3D.new()
    cache.name = "Cassa_scorte"
    cache.position = place
    add_child(cache)
    _box(cache,"Cassa",Vector3(0,.33,0),Vector3(.75,.66,.64),"#ad844d")
    _box(cache,"Fascia",Vector3(0,.39,0),Vector3(.79,.12,.68),"#e2bd69")
    var label := Label3D.new()
    label.text = "SCORTE"
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.position = Vector3(0,1.15,0)
    label.font_size = 30
    label.pixel_size = .006
    cache.add_child(label)
    supply_caches.append({"node":cache})

func _update_supply_caches(delta: float) -> void:
    for entry in supply_caches.duplicate():
        var obj: Node3D = entry["node"]
        if not is_instance_valid(obj):
            supply_caches.erase(entry)
            continue
        if hero.global_position.distance_to(obj.global_position) < 1.35:
            wood += 12
            coins += 9
            collected_supplies += 1
            show_message("SCORTE RECUPERATE: +12 legno, +9 monete",2.6)
            supply_caches.erase(entry)
            obj.queue_free()
            next_cache_spawn = maxf(next_cache_spawn,elapsed + 18.0)
            if collected_supplies >= supply_goal:
                collected_supplies = 0
                supply_goal += 2
                wood += 25
                coins += 18
                show_message("OBIETTIVO SCORTE COMPLETATO! +25 LEGNO +18 MONETE",4.0)
                _save_progress()
    if elapsed >= next_cache_spawn and supply_caches.size() < 3:
        _spawn_supply_cache()
        next_cache_spawn = elapsed + 26.0

func _save_directory() -> String:
    if OS.has_feature("standalone"):
        return OS.get_executable_path().get_base_dir().path_join("salvataggi")
    return ProjectSettings.globalize_path("user://salvataggi")

func _wall_hp_for_save() -> Array:
    var saved: Array = []
    for section in wall_segments:
        saved.append(float(section["hp"]))
    return saved

func _save_progress() -> void:
    # Durante la chiusura della scena il protagonista puo' essere gia' stato liberato.
    # Mai creare/troncare partita.json prima di sapere che i dati sono leggibili.
    if not is_instance_valid(hero):
        return
    var directory := _save_directory()
    var result := DirAccess.make_dir_recursive_absolute(directory)
    if result != OK:
        return
    var path := directory.path_join("partita.json")
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        return
    var radio_finished: int = radio_station.completed if is_instance_valid(radio_station) else 0
    var radio_ready: float = radio_station.next_ready if is_instance_valid(radio_station) else 0.0
    var data := {"version":8,"radio_finished":radio_finished,"radio_next_ready":radio_ready,"collected_supplies":collected_supplies,"supply_goal":supply_goal,"wood":wood,"coins":coins,"kills":kills,"weapon_level":weapon_level,"base_hp":base_hp,"wall_hp":_wall_hp_for_save(),"defense_hp_scale":WALL_HP_MAX,"gate_hp":gate_hp,"bench_hp":bench_hp,"camera_distance":camera_distance,"stockade_built":stockade_built,"gate_broken":gate_broken,"elapsed":elapsed,"next_raid":next_raid,"raid_number":raid_number,"px":hero.position.x,"pz":hero.position.z,"hp":hero.hp}
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
    collected_supplies = int(parsed.get("collected_supplies",0))
    supply_goal = int(parsed.get("supply_goal",4))
    wood = int(parsed.get("wood",0))
    coins = int(parsed.get("coins",0))
    kills = int(parsed.get("kills",0))
    weapon_level = int(parsed.get("weapon_level",1))
    base_hp = clampf(float(parsed.get("base_hp",150.0)),0.0,CABIN_HP_MAX)
    bench_hp = clampf(float(parsed.get("bench_hp",BENCH_HP_MAX)),0.0,BENCH_HP_MAX)
    elapsed = float(parsed.get("elapsed",0.0))
    next_raid = maxf(elapsed + 180.0,float(parsed.get("next_raid",FIRST_RAID_TIME)))
    raid_number = int(parsed.get("raid_number",0))
    if is_instance_valid(radio_station):
        radio_station.completed = int(parsed.get("radio_finished",0))
        radio_station.next_ready = float(parsed.get("radio_next_ready",0.0))
    hero.hp = float(parsed.get("hp",100.0))
    hero._update_health_bar()
    hero.global_position = Vector3(float(parsed.get("px",0.0)), .13, float(parsed.get("pz",7.0)))
    stockade_built = bool(parsed.get("stockade_built",false))
    gate_broken = bool(parsed.get("gate_broken",false))
    camera_distance = clampf(float(parsed.get("camera_distance",1.0)),0.62,1.75)
    if stockade_built:
        _build_stockade()
        gate_hp = clampf(float(parsed.get("gate_hp",GATE_HP_MAX)) * (GATE_HP_MAX/110.0) if not parsed.has("defense_hp_scale") else float(parsed.get("gate_hp",GATE_HP_MAX)),0.0,GATE_HP_MAX)
        if is_instance_valid(gate_indicator):
            gate_indicator.visible = gate_hp < GATE_HP_MAX*0.5
            gate_indicator.text = "CANCELLO %d/%d" % [ceili(gate_hp),int(GATE_HP_MAX)]
        var saved_wall_hp = parsed.get("wall_hp",[])
        if saved_wall_hp is Array:
            for i in range(mini(saved_wall_hp.size(),wall_segments.size())):
                wall_segments[i]["hp"] = clampf(float(saved_wall_hp[i]) * (WALL_HP_MAX/90.0) if not parsed.has("defense_hp_scale") else float(saved_wall_hp[i]),0.0,WALL_HP_MAX)
                var hp_now: float = float(wall_segments[i]["hp"])
                var indicator: Label3D = wall_segments[i]["indicator"]
                indicator.visible = hp_now < WALL_HP_MAX * 0.5
                var crack: MeshInstance3D = wall_segments[i]["crack"]
                crack.visible = hp_now < WALL_HP_MAX * 0.5 and hp_now > 0.0
                indicator.text = "BRECCIA!" if hp_now <= 0.0 else "MURO %d/%d" % [ceili(hp_now),int(WALL_HP_MAX)]
                if hp_now <= 0.0:
                    for mesh in wall_segments[i]["visuals"]:
                        if is_instance_valid(mesh):
                            mesh.visible = false
                    var collider: CollisionShape3D = wall_segments[i]["collider"]
                    collider.set_deferred("disabled",true)
    _sync_structure_visuals()
    show_message("Partita recuperata dai salvataggi.", 3.0)

func _exit_tree() -> void:
    if not skip_save_on_exit and is_instance_valid(hero):
        _save_progress()

func _repair_all_at_bench() -> void:
    if paused or bench_hp <= 0.0 or hero.global_position.distance_to(repair_bench.global_position) > 4.4:
        repair_popup.hide()
        return
    _build_or_repair()
    repair_popup.hide()

func _manual_position(kind: String) -> Vector3:
    if kind.begins_with("wall:"):
        return wall_segments[int(kind.get_slice(":",1))]["position"]
    if kind == "gate":
        return Vector3(0,0,4)
    if kind == "bench":
        return repair_bench.global_position
    return Vector3(0,0,-3.6)

func _inspect_structure(cursor: Vector2) -> void:
    var origin: Vector3 = camera.project_ray_origin(cursor)
    var direction: Vector3 = camera.project_ray_normal(cursor)
    var candidates: Array[Dictionary] = [
        {"kind":"cabin","title":"Rifugio","hp":base_hp,"max":CABIN_HP_MAX,
         "center":Vector3(0,1.6,-3.6),"size":Vector3(4.6,3.2,5.6)}
    ]
    if stockade_built:
        candidates.append({"kind":"gate","title":"Cancello","hp":gate_hp,"max":GATE_HP_MAX,
            "center":Vector3(0,1.1,4),"size":Vector3(2.9,2.2,.6)})
        candidates.append({"kind":"bench","title":"Banco","hp":bench_hp,"max":BENCH_HP_MAX,
            "center":repair_bench.global_position+Vector3.UP*.7,"size":Vector3(1.8,1.4,.92)})
        for i in range(wall_segments.size()):
            var section: Dictionary = wall_segments[i]
            var size: Vector3 = (section["collider"].shape as BoxShape3D).size
            candidates.append({"kind":"wall:%d" % i,"title":str(section["name"]),
                "hp":float(section["hp"]),"max":WALL_HP_MAX,
                "center":section["position"]+Vector3.UP*size.y*.5,"size":size})
    var kind: String = ""
    var title: String = ""
    var health: float = 0.0
    var maximum: float = 0.0
    var nearest: float = INF
    for candidate in candidates:
        var size: Vector3 = candidate["size"]
        var bounds := AABB(candidate["center"]-size*.5,size)
        var hit = bounds.intersects_ray(origin,direction)
        if hit == null:
            continue
        var distance: float = origin.distance_squared_to(hit)
        if distance < nearest:
            nearest = distance
            kind = candidate["kind"]
            title = candidate["title"]
            health = candidate["hp"]
            maximum = candidate["max"]
    if kind == "":
        return
    manual_target = kind
    hero.clear_mouse_destination()
    last_mouse_button = false
    var body: VBoxContainer = repair_popup.get_node("Menu")
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()
    var label := Label.new()
    label.text = "%s | %d / %d HP" % [title,ceili(health),int(maximum)]
    body.add_child(label)
    var cost: int = 12 if kind == "cabin" else BENCH_REPAIR_COST
    var near: bool = hero.global_position.distance_to(_manual_position(kind)) <= 4.4
    var button := Button.new()
    button.text = "Ripara | %d legno" % cost if near else "Avvicinati per riparare"
    button.disabled = not near or wood < cost or health >= maximum
    button.pressed.connect(func(): _repair_selected(kind))
    body.add_child(button)
    var close := Button.new()
    close.text = "Chiudi"
    close.pressed.connect(func(): repair_popup.hide())
    body.add_child(close)
    repair_popup.popup_centered()
