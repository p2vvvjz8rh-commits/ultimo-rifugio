extends CharacterBody3D
## Il giocatore usa gli scheletri animati del modello Quaternius.

var game
var visual
var hp: float = 100.0
# Bilanciamento temporaneo per il collaudo: guarigione automatica dopo 4 secondi senza danni.
const REGEN_WAIT := 4.0
const REGEN_HP_PER_SECOND := 9.0
const DAMAGE_MULTIPLIER := 0.70
const HIT_GRACE_SECONDS := 0.55
var since_last_hit: float = 999.0
var hit_grace: float = 0.0
var regen_ui_timer: float = 0.0
var attack_cooldown: float = 0.0
var chop_cooldown: float = 0.0
var action_timer: float = 0.0
var special_cooldown: float = 0.0
var dash_cooldown: float = 0.0
var dash_time: float = 0.0
var last_direction := Vector3(0.0, 0.0, -1.0)
var mouse_destination: Vector3
var mouse_has_destination := false
var health_sprite: Sprite3D
var health_text: Label3D

func configure(parent_game: Node3D) -> void:
    game = parent_game
    name = "Sopravvissuto"
    collision_layer = 2
    collision_mask = 1
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.55
    collision.shape = capsule
    collision.position.y = 0.79
    add_child(collision)
    visual = preload("res://scripts/actor_visual.gd").new()
    visual.name = "Aspetto3D"
    add_child(visual)
    visual.setup("res://assets/Characters_Shaun.gltf", 1.0)
    mouse_destination = global_position
    _create_health_bar()

func _create_health_bar() -> void:
    health_sprite = Sprite3D.new()
    health_sprite.name = "Barra_vita_sopra_protagonista"
    health_sprite.position = Vector3(0.0,2.55,0.0)
    health_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    health_sprite.no_depth_test = true
    health_sprite.shaded = false
    health_sprite.pixel_size = 0.008
    add_child(health_sprite)
    health_text = Label3D.new()
    health_text.name = "Vita_numerica"
    health_text.position = Vector3(0.0,2.96,0.0)
    health_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    health_text.no_depth_test = true
    health_text.font_size = 30
    health_text.pixel_size = 0.006
    health_text.outline_size = 6
    health_text.modulate = Color("#ffffff")
    health_text.outline_modulate = Color("#132019")
    add_child(health_text)
    _update_health_bar()

func _update_health_bar() -> void:
    if health_sprite == null:
        return
    health_sprite.visible = hp < 99.99
    health_text.visible = health_sprite.visible
    health_text.text = "%d/100" % ceili(hp)
    if not health_sprite.visible:
        return
    var img := Image.create(152,46,false,Image.FORMAT_RGBA8)
    img.fill(Color("#17211ce9"))
    img.fill_rect(Rect2i(3,4,146,38),Color("#331e1e"))
    var width: int = clampi(roundi(146.0 * hp / 100.0),0,146)
    if width > 0:
        var fill_color: Color = Color("#ee4444") if hp <= 25.0 else (Color("#f2a13d") if hp <= 50.0 else Color("#58d978"))
        img.fill_rect(Rect2i(3,4,width,38),fill_color)
    health_sprite.texture = ImageTexture.create_from_image(img)

func set_mouse_destination(point: Vector3) -> void:
    mouse_has_destination = true
    mouse_destination = point

func clear_mouse_destination() -> void:
    mouse_has_destination = false

func _physics_process(delta: float) -> void:
    if game == null or game.paused:
        velocity = Vector3.ZERO
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    chop_cooldown = maxf(0.0, chop_cooldown - delta)
    action_timer = maxf(0.0, action_timer - delta)
    special_cooldown = maxf(0.0, special_cooldown - delta)
    dash_cooldown = maxf(0.0, dash_cooldown - delta)
    dash_time = maxf(0.0, dash_time - delta)
    hit_grace = maxf(0.0, hit_grace - delta)
    since_last_hit += delta
    if hp < 100.0 and since_last_hit >= REGEN_WAIT:
        hp = minf(100.0, hp + REGEN_HP_PER_SECOND * delta)
        regen_ui_timer += delta
        if regen_ui_timer >= 0.10 or hp >= 100.0:
            regen_ui_timer = 0.0
            _update_health_bar()
    var direction := Vector3.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        direction.z -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        direction.z += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction.x += 1.0
    # WASD segue l'orientamento effettivo della camera; le destinazioni mouse restano nel mondo.
    if direction.length_squared() > .1:
        direction = direction.rotated(Vector3.UP,game.camera_yaw_current)
    if direction.length_squared() < 0.1 and mouse_has_destination:
        var delta_goal := mouse_destination - global_position
        delta_goal.y = 0.0
        if delta_goal.length() > 0.28:
            direction = delta_goal.normalized()
        else:
            mouse_has_destination = false
    else:
        if direction.length_squared() > 0.1:
            mouse_has_destination = false
    if direction.length_squared() > 0.1:
        direction = direction.normalized()
        last_direction = direction
        visual.look_toward(direction, delta)
    # Invito morbido verso il centro del cancello quando ci si entra o esce.
    # Non altera il movimento laterale lungo le mura.
    if game.stockade_built and absf(direction.z) > 0.25:
        if global_position.z > game.gate_front_z()-1.6 and global_position.z < game.gate_front_z()+2.7 and absf(global_position.x) < 3.1:
            var pull: float = clampf(-global_position.x * 0.9,-1.0,1.0)
            direction.x = lerpf(direction.x,pull,0.72)
            direction = direction.normalized()
            last_direction = direction
            visual.look_toward(direction,delta)
    var before_move: Vector3 = global_position
    var speed := 4.2 if dash_time <= 0.0 else 9.0
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    velocity.y = -0.5
    move_and_slide()
    global_position = game.frontier.clamp_hero(global_position)
    # L'intenzione di movimento non basta: contro un ostacolo si resta fermi.
    var moved := Vector2(global_position.x-before_move.x,global_position.z-before_move.z)
    var moving_now: bool = moved.length() > maxf(delta,.001)*.12
    if action_timer <= 0.0:
        visual.play_clip("Walk" if moving_now else "Idle", 1.15)
    var enemy = game.closest_enemy(global_position, 1.95)
    if enemy != null:
        if attack_cooldown <= 0.0:
            _attack(enemy, moving_now)
    elif chop_cooldown <= 0.0:
        var tree = game.closest_tree(global_position, 1.95)
        if tree != null:
            chop_cooldown = 0.72
            action_timer = 0.45
            visual.play_clip("Slash", 1.2, true)
            game.chop_tree(tree)

func _attack(target: Node3D, moving_now: bool = false) -> void:
    # Quando cammina, il giocatore guarda dove si sta muovendo anche durante gli attacchi automatici.
    # Da fermo si volta verso lo zombie per rendere il colpo leggibile.
    if not moving_now:
        var diff := target.global_position - global_position
        diff.y = 0.0
        if diff.length_squared() > 0.0001:
            visual.look_toward(diff.normalized(), 1.0)
    attack_cooldown = 0.72
    action_timer = 0.48
    visual.play_clip("Slash", 1.25, true)
    target.take_damage(23.0 + game.weapon_level * 7.0)
    game.make_noise(global_position, 5.0)

func special_attack() -> void:
    if special_cooldown > 0.0 or game.paused:
        return
    special_cooldown = 7.0
    attack_cooldown = maxf(attack_cooldown, 0.5)
    action_timer = 0.62
    visual.play_clip("Slash", 1.05, true)
    game.make_noise(global_position, 9.0)
    for enemy in game.enemies.duplicate():
        if is_instance_valid(enemy) and not enemy.defeated and global_position.distance_to(enemy.global_position) < 3.15:
            enemy.take_damage(46.0 + game.weapon_level * 10.0)
    game.show_message("COLPO AMPIO!", 1.2)

func dash() -> void:
    if dash_cooldown > 0.0 or game.paused:
        return
    dash_cooldown = 3.6
    dash_time = 0.22

func receive_damage(amount: float) -> void:
    if hit_grace > 0.0 or hp <= 0.0:
        return
    hit_grace = HIT_GRACE_SECONDS
    since_last_hit = 0.0
    regen_ui_timer = 0.0
    hp = maxf(0.0, hp - amount * DAMAGE_MULTIPLIER)
    _update_health_bar()
    if hp <= 0.0:
        game.frontier.leave_area(false)
        game.expedition.fail()
        game.salvage.drop_carried()
        hp = 100.0
        _update_health_bar()
        global_position = Vector3(0, 0.16, game.gate_front_z()+2.7)
        game.coins = maxi(0, int(game.coins * 0.8))
        game.show_message("Sei tornato al rifugio. Hai perso il 20% delle monete.", 3.0)
        game._save_progress()
