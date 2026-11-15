extends Node3D
## ALFA 12 - componente riutilizzabile per TUTTE le costruzioni.
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

func _create_marks() -> void:
    # Danni di forma e posizione diverse per ogni categoria, senza sola variazione cromatica.
    match structure_kind:
        "wall":
            _piece(light_damage,Vector3(-.45,-.32,.27),Vector3(.16,.72,.12),Color("#493021"),.46)
            _piece(light_damage,Vector3(.20,-.7,.28),Vector3(.11,.45,.12),Color("#c99b67"),-.42)
            _piece(heavy_damage,Vector3(.38,-.38,.31),Vector3(.21,1.22,.14),Color("#473025"),.54)
            _piece(heavy_damage,Vector3(-.32,-.9,.28),Vector3(.65,.15,.17),Color("#533a28"),-.22)
        "gate":
            _piece(light_damage,Vector3(-.55,-.45,.27),Vector3(.11,.95,.13),Color("#4c3427"),.26)
            _piece(heavy_damage,Vector3(.48,-.5,.3),Vector3(.17,1.42,.17),Color("#442d25"),-.48)
            _piece(heavy_damage,Vector3(0,-1.2,.3),Vector3(.92,.13,.2),Color("#63442e"),.34)
        "cabin":
            _piece(light_damage,Vector3(-.85,-1.5,2.04),Vector3(.13,.95,.11),Color("#503623"),.40)
            _piece(light_damage,Vector3(.67,-1.0,2.07),Vector3(.12,.65,.12),Color("#493426"),-.35)
            _piece(heavy_damage,Vector3(-1.02,-.65,1.65),Vector3(.62,.16,.17),Color("#59402d"),-.38)
            _piece(heavy_damage,Vector3(.9,-1.9,2.02),Vector3(.19,1.27,.18),Color("#493126"),.33)
            _piece(heavy_damage,Vector3(.15,-.45,1.9),Vector3(.7,.14,.13),Color("#402f27"),.28)
        "bench":
            _piece(light_damage,Vector3(-.27,-.46,.52),Vector3(.16,.52,.13),Color("#513624"),.38)
            _piece(heavy_damage,Vector3(.32,-.6,.53),Vector3(.18,.78,.13),Color("#462f24"),-.45)
            _piece(heavy_damage,Vector3(0,-.96,.5),Vector3(.8,.14,.15),Color("#755039"),.32)
        _:
            _piece(light_damage,Vector3(0,-.4,.25),Vector3(.1,.65,.1),Color("#513c2d"),.35)
            _piece(heavy_damage,Vector3(.2,-.5,.25),Vector3(.23,.86,.13),Color("#4c2b26"),-.42)
    var fallen_y: float = -2.63
    match structure_kind:
        "cabin":
            fallen_y = -3.90
        "gate":
            fallen_y = -2.87
        "bench":
            fallen_y = -2.05
    for index in range(5):
        var x: float = (float(index)-2.0) * .29
        _piece(rubble,Vector3(x,fallen_y + float(index%2)*.055,.10),Vector3(.42,.13,.31),Color("#866346"),float(index%3)*.23)

func set_health(value: float) -> void:
    hp = clampf(value,0.0,max_hp)
    var percent: float = hp / maxf(max_hp,1.0)
    light_damage.visible = percent < .999 and percent > 0.0
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
