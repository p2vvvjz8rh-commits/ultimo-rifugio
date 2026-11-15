extends CharacterBody3D
## IA semplice ma stabile: movimento e attacco sono stati separati.
## Il bruto compare soltanto nelle orde; il corridore ha una corsa distinta.

var game
var visual
var variant: String = "normal"
var from_wave: bool = false
var defeated: bool = false
var hp: float = 50.0
var speed: float = 2.0
var attack_cooldown: float = 0.0
var attack_animation_time: float = 0.0
var dying_time: float = 0.0
var wandering_angle: float = 0.0

func configure(parent_game: Node3D, zombie_variant: String, wave_zombie: bool) -> void:
    game = parent_game
    variant = zombie_variant
    from_wave = wave_zombie
    name = "Zombie_" + variant
    collision_layer = 2
    collision_mask = 1
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.38 if variant != "brute" else 0.62
    capsule.height = 1.5 if variant != "brute" else 2.3
    collider.shape = capsule
    collider.position.y = capsule.height * 0.5
    add_child(collider)
    visual = preload("res://scripts/actor_visual.gd").new()
    visual.name = "Aspetto3D"
    add_child(visual)
    if variant == "brute":
        hp = 175.0
        speed = 1.55
        visual.setup("res://assets/Zombie_Chubby.gltf", 1.33)
    elif variant == "runner":
        hp = 32.0
        speed = 3.5
        visual.setup("res://assets/Zombie_Basic.gltf", 0.85)
    else:
        hp = 48.0
        speed = 2.0
        visual.setup("res://assets/Zombie_Basic.gltf", 1.0)
    wandering_angle = randf_range(0, TAU)
    visual.play_clip("Idle")

func take_damage(amount: float) -> void:
    if defeated:
        return
    hp -= amount
    if hp <= 0.0:
        defeated = true
        dying_time = 1.45
        velocity = Vector3.ZERO
        visual.play_clip("Death", 1.0, true)
        game.coins += 15 if variant == "brute" else 6
        game.kills += 1
        game.show_message("+%d monete" % (15 if variant == "brute" else 6), 0.85)
    else:
        # La camminata riprende dopo la reazione al colpo, non durante l'attacco.
        attack_animation_time = maxf(attack_animation_time, 0.24)

func _physics_process(delta: float) -> void:
    if game == null or game.paused:
        return
    if defeated:
        dying_time -= delta
        if dying_time <= 0.0:
            queue_free()
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    attack_animation_time = maxf(0.0, attack_animation_time - delta)
    var target_point := Vector3.ZERO
    var attack_player := false
    var base_target := false
    var player_distance := global_position.distance_to(game.hero.global_position)
    var hears_noise: bool = not from_wave and game.noise_time > 0.0 and global_position.distance_to(game.noise_position) < 9.0
    if (player_distance < 4.4 or hears_noise) and game.has_clear_path(global_position, game.hero.global_position):
        target_point = game.hero.global_position
        attack_player = true
    elif from_wave:
        target_point = game.defense_target(global_position)
        base_target = true
    else:
        # Uno zombie vagante resta nello spazio di esplorazione.
        wandering_angle += delta * 0.23
        target_point = global_position + Vector3(cos(wandering_angle), 0, sin(wandering_angle)) * 2.5
    var to_target := target_point - global_position
    to_target.y = 0
    var distance := to_target.length()
    var range_limit := 1.1 if attack_player else 1.55
    if variant == "brute":
        range_limit += 0.34
    if base_target and game.stockade_built:
        range_limit = 0.60 if variant != "brute" else 0.85
    if distance <= range_limit and (attack_player or base_target):
        velocity = Vector3.ZERO
        if distance > 0.05:
            visual.look_toward(to_target.normalized(), delta)
        # Lo zombie smette di camminare prima di iniziare l'animazione d'attacco.
        if attack_cooldown <= 0.0:
            attack_cooldown = 1.25 if variant != "brute" else 1.75
            attack_animation_time = 0.70
            visual.play_clip("Punch", 1.0, true)
            if attack_player:
                game.hero.receive_damage(9.0 if variant != "brute" else 19.0)
            elif base_target:
                game.attack_defense_at(global_position,10.0 if variant != "brute" else 24.0)
        elif attack_animation_time <= 0.0:
            visual.play_clip("Idle", 1.0)
    else:
        if distance > 0.05:
            var direction := to_target.normalized()
            visual.look_toward(direction, delta)
            velocity.x = direction.x * speed
            velocity.z = direction.z * speed
            velocity.y = -0.5
            move_and_slide()
        if attack_animation_time <= 0.0:
            visual.play_clip("Run" if variant == "runner" else "Walk", 1.0)