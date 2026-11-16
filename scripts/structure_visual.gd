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

# Le varianti sostituiscono le mesh sane, senza toccare corpi o collisioni.
# bind_meshes e' il contratto comune anche per costruzioni future.
var bound_meshes: Array[Dictionary] = []
var damage_stage: int = -1

func bind_meshes(meshes: Array) -> void:
    for entry in bound_meshes:
        for variant in entry["variants"]:
            variant.queue_free()
    bound_meshes.clear()
    for item in meshes:
        if not is_instance_valid(item) or not item is MeshInstance3D:
            continue
        var variants: Array[Node3D] = []
        for stage in [1,2]:
            var variant := Node3D.new()
            variant.name = "Geometria_danneggiata_%d" % stage
            item.get_parent().add_child(variant)
            variant.transform = item.transform
            _build_variant(variant,item,stage,bound_meshes.size())
            variant.visible = false
            variants.append(variant)
        bound_meshes.append({"mesh":item,"transform":item.transform,"variants":variants})
    _build_debris()
    damage_stage = -1
    set_health(hp)

func _create_marks() -> void:
    pass # I detriti sono ricavati dall'ingombro reale delle mesh associate.

func _jagged_piece(parent: Node3D, dimensions: Vector3, at: Vector3, material: Material, seed_index: int) -> MeshInstance3D:
    # Prisma con estremita' spezzata: taglio irregolare nella geometria, non decal.
    var x: float = dimensions.x*.5
    var z: float = dimensions.z*.5
    var bottom: float = -dimensions.y*.5
    var top: float = dimensions.y*.5
    var vertices: Array[Vector3] = [
        Vector3(-x,bottom,-z),Vector3(x,bottom,-z),Vector3(x,bottom,z),Vector3(-x,bottom,z),
        Vector3(-x,top-dimensions.y*.16,-z),Vector3(x,top+dimensions.y*.10,-z),
        Vector3(x,top-dimensions.y*.23,z),Vector3(-x,top+dimensions.y*.07,z)]
    if seed_index%2 == 0:
        vertices[4].y += dimensions.y*.18
        vertices[5].y -= dimensions.y*.24
    var triangles: Array[int] = [0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7]
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in triangles:
        surface.add_vertex(vertices[index])
    surface.generate_normals()
    var model := MeshInstance3D.new()
    model.mesh = surface.commit()
    model.material_override = material
    model.position = at
    parent.add_child(model)
    return model

func _split_board(parent: Node3D, dimensions: Vector3, at: Vector3, axis: int, material: Material, stage: int, index: int) -> void:
    var holder := Node3D.new()
    parent.add_child(holder)
    holder.position = at
    var width: float = dimensions.x
    var height: float = dimensions.y
    var depth: float = dimensions.z
    if axis == 0:
        width = dimensions.y
        height = dimensions.x
        holder.rotation.z = -PI*.5
    elif axis == 2:
        depth = dimensions.y
        height = dimensions.z
        holder.rotation.x = PI*.5
    # Una tavola su quattro manca completamente nello stadio grave.
    if stage == 2 and index%4 == 1:
        return
    if stage == 2 and index%4 == 0:
        var remaining := _jagged_piece(holder,Vector3(width*.9,height*.82,depth),Vector3(0,-height*.09,0),material,index)
        remaining.rotation.z = .14 if index%2 == 0 else -.14
        return
    var lower_height: float = height*((.42+float(index%3)*.06) if stage == 1 else (.28+float(index%3)*.09))
    var lower := _jagged_piece(holder,Vector3(width*.93,lower_height,depth),Vector3(0,-height*.5+lower_height*.5,0),material,index)
    lower.rotation.z = -.08 if index%2 == 0 else .10
    if stage == 1:
        var upper_height: float = height*(.48-float(index%3)*.06)
        var upper := _jagged_piece(holder,Vector3(width*.90,upper_height,depth),Vector3(width*.22,height*.5-upper_height*.5,depth*.12),material,index+1)
        upper.rotation.z = .17 if index%2 == 0 else -.21
        upper.rotation.x = .08 if stage == 1 else .30
    # Lo spazio tra i monconi resta realmente vuoto e leggibile da entrambi i lati.

func _build_variant(parent: Node3D, item: MeshInstance3D, stage: int, index: int) -> void:
    var title: String = str(item.get_meta("visual_role",String(item.name)))
    var material: Material = item.material_override
    if not item.mesh is BoxMesh:
        # Le punte saltano dove il legno sottostante e' spezzato.
        if title.begins_with("Punta") and (stage == 2 or index%2 == 0):
            return
        var copy := MeshInstance3D.new()
        copy.mesh = item.mesh
        copy.material_override = material
        parent.add_child(copy)
        copy.rotation.z = .16 if stage == 1 else .32
        return
    var size: Vector3 = (item.mesh as BoxMesh).size
    if title == "Pareti":
        # Il blocco pieno della casetta viene sostituito da quattro pareti di assi:
        # i vuoti non vengono nascosti da una seconda scatola integra.
        for side in range(4):
            var face := Node3D.new()
            parent.add_child(face)
            face.rotation.y = float(side)*PI*.5
            face.position = Vector3(sin(float(side)*PI*.5)*size.x*.5,0,cos(float(side)*PI*.5)*size.z*.5)
            for board in range(8):
                _split_board(face,Vector3(size.x/8.0-.025,size.y,.14),Vector3(-size.x*.5+(float(board)+.5)*size.x/8.0,0,0),1,material,stage,board+side)
        return
    if title.begins_with("Legno_anta"):
        for board in range(4):
            _split_board(parent,Vector3(size.x/4.0-.025,size.y,size.z),Vector3(-size.x*.5+(float(board)+.5)*size.x/4.0,0,0),1,material,stage,board+index)
        return
    if title.begins_with("Tetto") or title == "Banco_piano":
        # Pannelli divisi in tavole: grandi lacune irregolari sul tetto e sul piano.
        for board in range(6):
            _split_board(parent,Vector3(size.x,size.y,size.z/6.0-.015),Vector3(0,0,-size.z*.5+(float(board)+.5)*size.z/6.0),0,material,stage,board+index)
        parent.rotation.z += -.06 if stage == 1 else -.18
        return
    var structural: bool = title.begins_with("Asse") or title.begins_with("Trave") or title.begins_with("Rinforzo") or title.begins_with("Banco_gamba") or title.begins_with("Colonna") or title.begins_with("Architrave") or title == "Porta"
    # Fallback per nuove costruzioni: una mesh scatolare portante riceve lo stesso sistema.
    if structural or (structure_kind not in ["wall","gate","cabin","bench"] and size.length() > .5):
        var axis: int = 1
        if size.x > size.y and size.x > size.z:
            axis = 0
        elif size.z > size.y:
            axis = 2
        _split_board(parent,size,Vector3.ZERO,axis,material,stage,index)
    else:
        # Accessori: restano appoggiati in fase lieve, alcuni cadono nello stadio grave.
        if stage == 2 and index%3 == 0:
            return
        var copy := MeshInstance3D.new()
        copy.mesh = item.mesh
        copy.material_override = material
        parent.add_child(copy)
        if stage == 2:
            copy.rotation.z = .25
            copy.position.y = -.15

func _build_debris() -> void:
    for container in [heavy_damage,rubble]:
        for child in container.get_children():
            child.queue_free()
    # I pezzi crollati coprono l'ingombro reale, anche sui lati lunghi del recinto.
    for index in range(bound_meshes.size()):
        var item: MeshInstance3D = bound_meshes[index]["mesh"]
        if not item.mesh is BoxMesh:
            continue
        var size: Vector3 = (item.mesh as BoxMesh).size
        if size.length() < .6:
            continue
        var at: Vector3 = to_local(item.global_position)
        at.y = -global_position.y+.13+float(index%3)*.07
        var length: float = clampf(maxf(size.x,maxf(size.y,size.z))*.68,.4,2.4)
        var fallen := _jagged_piece(rubble,Vector3(.20,length,.14),at,item.material_override,index)
        fallen.rotation = Vector3(PI*.5,float(index)*1.71,.12)
        if index%2 == 0:
            var chip := _jagged_piece(heavy_damage,Vector3(.13,length*.6,.10),at+Vector3(.2,0,.25),item.material_override,index)
            chip.rotation = Vector3(PI*.5,float(index)*2.13,0)

func _apply_damage(stage: int) -> void:
    if stage == damage_stage:
        return
    damage_stage = stage
    for entry in bound_meshes:
        var item: MeshInstance3D = entry["mesh"]
        if not is_instance_valid(item):
            continue
        item.transform = entry["transform"]
        item.visible = stage == 0
        entry["variants"][0].visible = stage == 1
        entry["variants"][1].visible = stage == 2

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
