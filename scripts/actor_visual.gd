extends Node3D
## Alfa 08: le animazioni Quaternius restano scheletriche, in vero 3D.
## Le animazioni di locomozione vengono messe in loop esplicitamente.

var animation_player: AnimationPlayer
var current_clip: String = ""
var missing_clips: Dictionary = {}

func setup(asset_path: String, model_scale: float = 1.0) -> void:
    var packed: PackedScene = load(asset_path) as PackedScene
    if packed == null:
        push_error("Modello 3D non caricato: " + asset_path)
        return
    var character: Node3D = packed.instantiate() as Node3D
    if character == null:
        push_error("Modello non istanziabile: " + asset_path)
        return
    add_child(character)
    character.scale = Vector3.ONE * model_scale
    if asset_path.contains("Characters_Shaun"):
        _select_club(character)
    animation_player = _find_animation_player(character)
    if animation_player == null:
        push_error("AnimationPlayer non trovato per: " + asset_path)
        return
    _configure_animation_loops()
    play_clip("Idle")

func _find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var found: AnimationPlayer = _find_animation_player(child)
        if found != null:
            return found
    return null

func _animation_simple_name(animation_key: String) -> String:
    # Le librerie importate possono anteporre un nome (es. "Animations/Walk").
    return animation_key.replace("|", "/").get_file().to_lower()

func _configure_animation_loops() -> void:
    if animation_player == null:
        return
    var locomotion: Array[String] = ["idle", "idle_gun", "walk", "walk_gun", "run", "run_arms", "run_gun", "run_slash", "run_stab", "crawl", "idle_attack"]
    for key in animation_player.get_animation_list():
        var full_name := String(key)
        var anim: Animation = animation_player.get_animation(key)
        if anim == null:
            continue
        if _animation_simple_name(full_name) in locomotion:
            anim.loop_mode = Animation.LOOP_LINEAR
        else:
            # L'attacco e la morte non devono ripetersi all'infinito.
            anim.loop_mode = Animation.LOOP_NONE

func _resolve_clip(clip_name: String) -> String:
    if animation_player == null:
        return ""
    var wanted := clip_name.to_lower()
    for available in animation_player.get_animation_list():
        var key := String(available)
        if _animation_simple_name(key) == wanted:
            return key
    return ""

func play_clip(clip_name: String, playback_speed: float = 1.0, force_restart: bool = false) -> void:
    if animation_player == null:
        return
    var resolved := _resolve_clip(clip_name)
    if resolved.is_empty():
        if not missing_clips.has(clip_name):
            missing_clips[clip_name] = true
            push_warning("Animazione assente: %s. Disponibili: %s" % [clip_name, str(animation_player.get_animation_list())])
        return
    if current_clip == resolved and not force_restart and animation_player.is_playing():
        return
    if force_restart and current_clip == resolved:
        animation_player.stop()
    current_clip = resolved
    animation_player.play(resolved, 0.14, playback_speed)

func look_toward(world_direction: Vector3, delta: float = 0.15) -> void:
    var planar := Vector2(world_direction.x, world_direction.z)
    if planar.length_squared() < 0.0001:
        return
    # Il mesh Quaternius guarda lungo +Z, non -Z come ipotizzato inizialmente.
    # Godot: rotazione Y=+90° orienta +Z verso +X (tasto D).
    var goal: float = atan2(world_direction.x, world_direction.z)
    rotation.y = lerp_angle(rotation.y, goal, clampf(delta * 13.0, 0.0, 1.0))

func _select_club(root: Node) -> void:
    var weapon_names := ["Axe", "Guitar", "Knife", "Pistol", "Rifle", "Shotgun", "SMG", "Spear", "WoodenBat_Barbed", "WoodenBat_Saw"]
    for child in root.get_children():
        if String(child.name) in weapon_names and child is Node3D:
            (child as Node3D).visible = String(child.name) == "WoodenBat_Barbed"
        _select_club(child)
