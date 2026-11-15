extends CharacterBody3D
## Il giocatore usa gli scheletri animati del modello Quaternius.

var game
var visual
var hp: float = 100.0
var attack_cooldown: float = 0.0
var chop_cooldown: float = 0.0
var action_timer: float = 0.0
var special_cooldown: float = 0.0
var dash_cooldown: float = 0.0
var dash_time: float = 0.0
var last_direction := Vector3(0.0, 0.0, -1.0)
var mouse_destination: Vector3
var mouse_has_destination := false

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
    var direction := Vector3.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        direction.z -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        direction.z += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction.x += 1.0
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
    var moving_now: bool = direction.length_squared() > 0.01
    var speed := 4.2 if dash_time <= 0.0 else 9.0
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    velocity.y = -0.5
    move_and_slide()
    global_position.x = clampf(global_position.x, -20.0, 20.0)
    global_position.z = clampf(global_position.z, -20.0, 20.0)
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
    hp = maxf(0.0, hp - amount)
    if hp <= 0.0:
        hp = 100.0
        global_position = Vector3(0, 0.16, 6.7)
        game.coins = maxi(0, int(game.coins * 0.8))
        game.show_message("Sei tornato al rifugio. Hai perso il 20% delle monete.", 3.0)
