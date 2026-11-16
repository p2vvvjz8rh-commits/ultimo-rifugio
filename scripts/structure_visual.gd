extends Node3D
## Deterioramento reversibile per ogni costruzione.
## Mostra una barra di vita solo sotto il 100% e due livelli di danno fisico.
## I proprietari controllano collisioni, crollo ed eventuale riparazione.

var max_hp: float = 100.0
var hp: float = 100.0
var structure_kind: String = "wall"
var bar: Sprite3D
var light_damage: Node3D
var heavy_damage: Node3D
var rubble: Node3D
var last_bar_hp: int = -1

func configure(kind: String, maximum: float, local_position: Vector3) -> void:
    structure_kind = kind
    max_hp = maximum
    hp = maximum
    position = local_position
    bar = Sprite3D.new()
    bar.name = "Barra_salute_struttura"
    bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    bar.no_depth_test = true
    bar.shaded = false
    bar.pixel_size = 0.008
    bar.position = Vector3.ZERO
    add_child(bar)
    light_damage = Node3D.new()
    light_damage.name = "Danni_lievi"
    add_child(light_damage)
    heavy_damage = Node3D.new()
    heavy_damage.name = "Danni_gravi"
    add_child(heavy_damage)
    rubble = Node3D.new()
    rubble.name = "Rovine"
    add_child(rubble)
    _create_marks()
    set_health(max_hp)

func _piece(parent: Node3D, at: Vector3, dimensions: Vector3, tone: Color, tilt: float = 0.0) -> MeshInstance3D:
    var model := MeshInstance3D.new()
    var cuboid := BoxMesh.new()
    cuboid.size = dimensions
    model.mesh = cuboid
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tone
    mat.roughness = 1.0
    model.material_override = mat
    model.position = at
    model.rotation.z = tilt
    parent.add_child(model)
    return model

# Ogni mesh conserva la trasformazione originale: nessun accumulo di deformazioni.
var bound_meshes: Array[Dictionary] = []
var damage_stage: int = -1

func bind_meshes(meshes: Array) -> void:
    bound_meshes.clear()
    for item in meshes:
        if is_instance_valid(item) and item is MeshInstance3D:
            bound_meshes.append({"mesh":item,"transform":item.transform})
    damage_stage = -1
    set_health(hp)

func _create_marks() -> void:
    # Schegge poggiate al suolo; niente assi sospese davanti alla struttura.
    for index in range(7):
        var x: float = (float(index)-3.0)*.23
        var piece := _piece(rubble,Vector3(x,-position.y+.10,float(index%3)*.19-.2),
            Vector3(.12,.09,.65+float(index%2)*.3),Color("#98704b"),.08)
        piece.rotation.y = float(index)*1.73
    for index in range(3):
        var chip := _piece(heavy_damage,Vector3(float(index-1)*.3,-position.y+.07,.35),
            Vector3(.07,.06,.35),Color("#ba9566"))
        chip.rotation.y = float(index)*2.1

func _apply_damage(stage: int) -> void:
    if stage == damage_stage:
        return
    damage_stage = stage
    for index in range(bound_meshes.size()):
        var entry: Dictionary = bound_meshes[index]
        var item: MeshInstance3D = entry["mesh"]
        if not is_instance_valid(item):
            continue
        item.transform = entry["transform"]
        item.visible = stage < 3
        if stage == 0 or stage == 3:
            continue
        # Les pieces porteuses restent en place; les planches se voilent localement.
        var title: String = String(item.name)
        var plank: bool = title.begins_with("Asse") or title.begins_with("Legno_anta") or title.begins_with("Banco_piano") or title.begins_with("Listello") or title.begins_with("Tetto")
        if plank:
            var sign_value: float = -1.0 if index%2 == 0 else 1.0
            item.rotation.z += sign_value * (.018 if stage == 1 else .065)
            item.position.y -= .015 if stage == 1 else .065
            if stage == 2:
                item.scale.y *= .88

func set_health(value: float) -> void:
    hp = clampf(value,0.0,max_hp)
    var percent: float = hp / maxf(max_hp,1.0)
    _apply_damage(3 if hp <= 0 else (0 if percent >= .999 else (1 if percent >= .5 else 2)))
    light_damage.visible = false
    heavy_damage.visible = percent < .50 and percent > 0.0
    rubble.visible = hp <= 0.0
    bar.visible = percent < .999
    var quantized: int = roundi(percent * 1000.0)
    if not bar.visible or quantized == last_bar_hp:
        return
    last_bar_hp = quantized
    var im := Image.create(144,32,false,Image.FORMAT_RGBA8)
    im.fill(Color("#142018ed"))
    im.fill_rect(Rect2i(4,4,136,24),Color("#442f2c"))
    var progress: int = clampi(roundi(136.0 * percent),0,136)
    var color: Color = Color("#52d77c") if percent > .5 else (Color("#f3c84e") if percent > .25 else Color("#e74a4c"))
    if progress > 0:
        im.fill_rect(Rect2i(4,4,progress,24),color)
    bar.texture = ImageTexture.create_from_image(im)
