extends Node3D
## ALFA 13 - punto radio per una piccola missione di recupero.
## Non aggiunge specie di zombie e non modifica il sistema di costruzione.

const DEFENSE_TIME := 32.0
const COOLDOWN_TIME := 180.0
const MAX_DISTANCE := 11.0

var game
var active: bool = false
var remaining: float = 0.0
var next_ready: float = 0.0
var completed: int = 0
var spawn_timer: float = 0.0
var away_timer: float = 0.0
var status_label: Label3D
var signal_light: OmniLight3D
var light_timer: float = 0.0

func configure(world: Node3D) -> void:
    game = world
    name = "Stazione_radio_abbandonata"
    position = Vector3(13.0,0.0,-10.0)
    _create_model()

func _material(tone: String) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(tone)
    material.roughness = .83
    return material

func _cuboid(title: String, at: Vector3, size: Vector3, tone: String) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = title
    var m := BoxMesh.new()
    m.size = size
    item.mesh = m
    item.material_override = _material(tone)
    item.position = at
    add_child(item)
    return item

func _create_model() -> void:
    _cuboid("Basamento cemento",Vector3(0.0,.12,0.0),Vector3(2.7,.24,2.4),"#6d776b")
    _cuboid("Armadio trasmittente",Vector3(0.0,.90,-.22),Vector3(1.25,1.65,.85),"#596f71")
    _cuboid("Sportello",Vector3(0.0,1.0,.25),Vector3(1.07,1.25,.05),"#84908b")
    _cuboid("Schermo",Vector3(-.22,1.25,.29),Vector3(.43,.28,.035),"#8bc7aa")
    for index in range(3):
        _cuboid("Manopola_%d" % index,Vector3(.30,1.30-float(index)*.22,.32),Vector3(.13,.1,.07),"#e5bf72")
    _cuboid("Antenna verticale",Vector3(.38,2.84,-.27),Vector3(.12,2.43,.12),"#b7baac")
    _cuboid("Antenna orizzontale",Vector3(.38,3.56,-.27),Vector3(1.18,.09,.11),"#c9cbb7")
    for step in range(3):
        _cuboid("Griglia_%d" % step,Vector3(-.23,.69-float(step)*.14,.3),Vector3(.56,.06,.045),"#495d57")
    _cuboid("Scatola batterie",Vector3(-1.15,.30,.70),Vector3(.47,.52,.66),"#736d55")
    _cuboid("Cassetta ricambi",Vector3(1.08,.26,.64),Vector3(.56,.43,.50),"#997b56")
    var beacon := MeshInstance3D.new()
    beacon.name = "Segnalatore"
    var sphere := SphereMesh.new()
    sphere.radius = .15
    sphere.height = .30
    beacon.mesh = sphere
    beacon.position = Vector3(.38,4.13,-.27)
    var beacon_mat := _material("#f8ca70")
    beacon_mat.emission_enabled = true
    beacon_mat.emission = Color("#ffc77a")
    beacon_mat.emission_energy_multiplier = 1.3
    beacon.material_override = beacon_mat
    add_child(beacon)
    signal_light = OmniLight3D.new()
    signal_light.name = "Luce_radio"
    signal_light.position = Vector3(.38,3.92,-.27)
    signal_light.omni_range = 5.5
    signal_light.light_color = Color("#ffc37a")
    signal_light.light_energy = .9
    add_child(signal_light)
    status_label = Label3D.new()
    status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    status_label.no_depth_test = true
    status_label.font_size = 30
    status_label.outline_size = 6
    status_label.pixel_size = .007
    status_label.position = Vector3(0.0,4.7,0.0)
    status_label.modulate = Color("#ffedc6")
    status_label.text = "SEGNALE RADIO"
    add_child(status_label)

func _process(delta: float) -> void:
    if game == null or game.paused:
        return
    light_timer += delta
    if is_instance_valid(signal_light):
        signal_light.light_energy = .4 + .42 * (1.0 + sin(light_timer*3.4)) * .5
    if not active:
        if game.elapsed < next_ready:
            status_label.text = "RADIO IN RICARICA  %ds" % ceili(next_ready-game.elapsed)
        elif game.hero.global_position.distance_to(global_position) < 3.3:
            status_label.text = "PREMI R  -  DIFENDI IL SEGNALE"
        else:
            status_label.text = "SEGNALE RADIO - RECUPERA MATERIALI"
        return
    remaining -= delta
    spawn_timer -= delta
    if game.hero.global_position.distance_to(global_position) > MAX_DISTANCE:
        away_timer += delta
    else:
        away_timer = 0.0
    if away_timer >= 5.0:
        active = false
        next_ready = game.elapsed + 35.0
        game.show_message("Segnale perso: torna alla radio per riprovare.",3.0)
        game._save_progress()
        return
    if spawn_timer <= 0.0 and remaining > 0.0:
        spawn_timer = 7.5
        _attract_zombies()
    if remaining <= 0.0:
        _finish()
        return
    status_label.text = "DIFENDI LA RADIO  %ds" % ceili(remaining)

func activate() -> void:
    if game == null or game.paused or active:
        return
    if game.hero.global_position.distance_to(global_position) > 3.3:
        game.show_message("Avvicinati alla stazione radio nel bosco.",2.2)
        return
    if game.elapsed < next_ready:
        game.show_message("Radio pronta fra %d secondi." % ceili(next_ready-game.elapsed),2.0)
        return
    active = true
    remaining = DEFENSE_TIME
    spawn_timer = 2.0
    away_timer = 0.0
    game.show_message("SEGNALE ATTIVATO: difendi la radio per 32 secondi!",4.0)
    game.make_noise(global_position,7.0)

func _attract_zombies() -> void:
    # Solo zombie normali, con un piccolo limite di popolazione per la demo.
    var alive: int = 0
    for enemy in game.enemies:
        if is_instance_valid(enemy) and not enemy.defeated:
            if enemy.global_position.distance_to(global_position) < 12.0:
                alive += 1
    if alive >= 6:
        return
    for i in range(2):
        var a: float = randf_range(0.0,TAU)
        var at: Vector3 = global_position + Vector3(cos(a)*7.0,.13,sin(a)*7.0)
        at.x = clampf(at.x,-19.0,19.0)
        at.z = clampf(at.z,-19.0,19.0)
        game._spawn_enemy(at,"normal",false)

func _finish() -> void:
    active = false
    completed += 1
    next_ready = game.elapsed + COOLDOWN_TIME
    game.wood += 25
    game.coins += 20
    status_label.text = "TRASMISSIONE COMPLETATA"
    game.show_message("RADIO DIFESA: +25 LEGNO E +20 MONETE!",4.0)
    game._save_progress()
