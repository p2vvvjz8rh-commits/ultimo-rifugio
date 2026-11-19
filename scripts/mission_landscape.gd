extends RefCounted
## Direzione artistica delle spedizioni. Geometria soltanto visiva, coordinate fisiche conservate.
static var mats: Dictionary = {}
static var textures: Dictionary = {}
static var patch_mats: Dictionary = {}
var batches: Dictionary = {}
var rng := RandomNumberGenerator.new()
var root: Node3D
var world

func material(color: String, surface: String = "paint") -> StandardMaterial3D:
    var key := color+surface
    if mats.has(key): return mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(color)
    m.roughness = .93
    m.metallic = .15 if surface == "metal" else 0.0
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    if not textures.has(surface):
        var image := Image.create(96,96,false,Image.FORMAT_RGB8)
        var noise := FastNoiseLite.new()
        noise.seed = 971
        noise.frequency = .095
        for y in range(96):
            for x in range(96):
                var n: float = noise.get_noise_2d(x,y)
                var fine := float((x*17+y*37)%13)/130.0
                var value := .95+n*.055+fine*.15
                if surface == "wood": value += sin(float(y)*.95+noise.get_noise_2d(x*.2,y)*3)*.09
                if surface == "metal": value -= .15 if (x%24 < 2 or y%47 < 2) else 0.0
                image.set_pixel(x,y,Color(value,value,value))
        image.generate_mipmaps()
        textures[surface] = ImageTexture.create_from_image(image)
    m.albedo_texture = textures[surface]
    mats[key] = m
    return m

func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: String, surface: String = "paint") -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = shape
    node.position = at
    node.material_override = material(color,surface)
    parent.add_child(node)
    return node
func box(parent: Node3D, at: Vector3, size: Vector3, color: String, surface: String = "metal") -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    return mesh(parent,shape,at,color,surface)
func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: String, top: float = -1.0) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.bottom_radius = radius
    shape.top_radius = radius if top < 0 else top
    shape.height = height
    shape.radial_segments = 12
    return mesh(parent,shape,at,color,"metal")
func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: String, surface: String = "metal") -> void:
    var node := box(parent,(a+b)*.5,Vector3(width,a.distance_to(b),width),color,surface)
    node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
func rock(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
    var shape := SphereMesh.new()
    shape.radius = .5
    shape.height = 1
    shape.radial_segments = 7
    shape.rings = 3
    var node := mesh(parent,shape,at,color,"stone")
    node.scale = size
    node.rotation = Vector3(rng.randf_range(-.2,.2),rng.randf()*TAU,rng.randf_range(-.2,.2))
    return node

func dress(game, place: Node3D, area: int) -> void:
    world = game
    rng.seed = 8150+area*301
    root = Node3D.new()
    root.name = "Diorama_spedizione"
    place.add_child(root)
    # Rimuove solo le superfici dei vecchi blocchi, non corpi/collisioni.
    for child in place.get_children():
        if child is StaticBody3D:
            for part in child.get_children():
                if part is MeshInstance3D: part.visible = false
        elif child is MeshInstance3D: child.visible = false
    terrain(area)
    perimeter(area)
    if area == 0: timber_yard()
    elif area == 1: utility_yard()
    else: survey_yard()
    ground_cover(area)
    entrance_sign()
    flush_batches()
    bake_small_props()
    root.set_meta("art_revision",2)
    root.set_meta("decorative_only",true)

func terrain(area: int) -> void:
    # Superficie continua, triangoli irregolari; quota giocabile piatta sopra il collider esistente.
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var palette: Array = [["#777b57","#7f795e","#696c4c"],["#6c7771","#858477","#5a6961"],["#868568","#7b8061","#626e52"]][area]
    var cells := 24
    var grid: Array = []
    for z in range(cells+1):
        var row: Array[Vector3] = []
        for x in range(cells+1):
            var px := -27.0+x*54.0/cells
            var pz := -26.0+z*52.0/cells
            if x > 0 and x < cells: px += rng.randf_range(-.6,.6)
            if z > 0 and z < cells: pz += rng.randf_range(-.6,.6)
            var outer := maxf(absf(px)/17.0,absf(pz)/15.0)
            var height := -.015 if outer < .97 else minf(1.8,(outer-.97)*3.0)+rng.randf_range(-.3,.3)
            row.append(Vector3(px,height,pz))
        grid.append(row)
    for z in range(cells):
        for x in range(cells):
            var shade := Color(palette[rng.randi_range(0,2)])
            shade = shade.lerp(Color(palette[0]),.9)
            for point in [grid[z][x],grid[z+1][x],grid[z][x+1],grid[z][x+1],grid[z+1][x],grid[z+1][x+1]]:
                surface.set_color(shade)
                surface.set_uv(Vector2(point.x,point.z)*.23)
                surface.add_vertex(point)
    surface.generate_normals()
    var ground := mesh(root,surface.commit(),Vector3.ZERO,"#ffffff","earth")
    var m := material("#ffffff","earth").duplicate() as StandardMaterial3D
    m.vertex_color_use_as_albedo = true
    ground.material_override = m
    ground.name = "Terreno_continuo"
    ground.set_meta("ground_surface",true)
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    # Tracce di ruote, piazzole e fango con bordi frastagliati, non dischetti in fila.
    patch(Vector3(0,.012,1),Vector2(5,12),"#77705b",151)
    for x in [-.65,.65]:
        patch(Vector3(x,.022,2),Vector2(.12,9),"#595b49",241+int(x*10))
    for at in [Vector3(-10,.025,5),Vector3(10,.025,-6),Vector3(0,.025,-10),Vector3(-10,.025,-7),Vector3(10,.025,6)]:
        patch(at,Vector2(2.3,1.9),"#827a61",int(at.x*13+at.z*7))
    if area == 1:
        patch(Vector3(0,.026,-1),Vector2(7.5,4.8),"#65756c",392)
        for at in [Vector3(-7,.027,5),Vector3(7,.027,-9)]: patch(at,Vector2(2.2,1.0),"#455d5d",91)
    else:
        patch(Vector3(12,.028,0),Vector2(1.4,4),"#777354",91)

func patch(at: Vector3, size: Vector2, color: String, seed_value: int) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var count := 18
    for i in range(count):
        var a := float(i)*TAU/count
        var b := float(i+1)*TAU/count
        var ra := .84+sin(float(i)*1.41+float(seed_value))*.09+cos(float(i)*.65+float(seed_value))*.07
        var rb := .84+sin(float(i+1)*1.41+float(seed_value))*.09+cos(float(i+1)*.65+float(seed_value))*.07
        for p in [Vector3.ZERO,Vector3(cos(b)*size.x*rb,0,sin(b)*size.y*rb),Vector3(cos(a)*size.x*ra,0,sin(a)*size.y*ra)]:
            st.set_color(Color(1,1,1,.7 if p == Vector3.ZERO else 0.0))
            st.set_uv(Vector2(p.x,p.z)*.5)
            st.add_vertex(p)
    st.generate_normals()
    var node := mesh(root,st.commit(),at,color,"earth")
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.set_meta("ground_surface",true)
    if not patch_mats.has(color):
        var patch_mat := material(color,"earth").duplicate() as StandardMaterial3D
        patch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        patch_mat.vertex_color_use_as_albedo = true
        patch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        patch_mats[color] = patch_mat
    node.material_override = patch_mats[color]

func perimeter(area: int) -> void:
    # Scarpata e bosco a livelli nascondono il rettangolo della vecchia arena.
    for side in [-1,1]:
        for j in range(13):
            var z := -16+j*2.65
            rock(root,Vector3(side*(17.5+rng.randf_range(-.4,1.2)),.35,z),Vector3(2.0,rng.randf_range(1.9,3.0),3.4),"#68705d")
        for j in range(11):
            var x := -17+j*3.4
            rock(root,Vector3(x,.45,side*(15.8+rng.randf_range(-.2,1))),Vector3(4,rng.randf_range(2.2,3),2.7),"#72745f")
    for i in range(30):
        var angle := float(i)*TAU/30
        var at := Vector3(cos(angle)*rng.randf_range(20,25),.8,sin(angle)*rng.randf_range(19,24))
        tree(at,rng.randf_range(.85,1.5),i%3 == 0)
    for side in [-1,1]:
        for z in [-10,0,10]: tree(Vector3(side*18.7,.55,z),1.1,false)
    # Silhouette proprie per ogni composizione, fuori dall'area di gioco.
    if area == 0:
        for x in [-13,-6]:
            beam(root,Vector3(x,1,-18),Vector3(x,6,-18),.25,"#827156")
        beam(root,Vector3(-13,6,-18),Vector3(-6,6,-18),.35,"#887852")
        beam(root,Vector3(-8,6,-18),Vector3(-8,3.8,-18),.07,"#4f5552")
        cylinder(root,Vector3(-8,3.8,-18),.2,.4,"#ab9864")
    elif area == 1:
        for x in [10,14]:
            for z in [-18,-21]: beam(root,Vector3(x,1,z),Vector3(x,6,z),.2,"#5c6e69")
        cylinder(root,Vector3(12,6.5,-19.5),2.3,3,"#88958b")
        cylinder(root,Vector3(12,8.2,-19.5),2.5,.4,"#566f69",.3)
        beam(root,Vector3(10,1,-18),Vector3(14,6,-18),.12,"#7c8980")
        beam(root,Vector3(14,1,-18),Vector3(10,6,-18),.12,"#7c8980")
    else:
        for y in range(7):
            var half := 1.2-float(y)*.13
            for x in [-half,half]: beam(root,Vector3(x,y+1,-20),Vector3(x*.85,y+2,-20),.1,"#8c9182")
            beam(root,Vector3(-half,y+1,-20),Vector3(half*.85,y+2,-20),.065,"#727e71")
        beam(root,Vector3(-3,6.5,-20),Vector3(3,6.5,-20),.15,"#c2b28a")

func tree(at: Vector3, size: float, bare: bool) -> void:
    var trunk := Node3D.new()
    root.add_child(trunk)
    trunk.position = at
    trunk.scale = Vector3.ONE*size
    cylinder(trunk,Vector3(0,2.8,0),.32,5.6,"#66523d",.16)
    for i in range(4):
        var angle := i*2.4
        var tip := Vector3(cos(angle)*1.4,3.3+float(i)*.65,sin(angle)*1.4)
        beam(trunk,Vector3(0,2.2+i*.55,0),tip,.12,"#746047","wood")
        if not bare:
            rock(trunk,tip+Vector3(0,.7,0),Vector3(3,2.5,2.5),["#3b5b45","#526c49","#667849"][i%3])
    if not bare: rock(trunk,Vector3(0,5.7,0),Vector3(2.8,3.0,2.7),"#526a46")

func container(at: Vector3, color: String) -> void:
    var parent := Node3D.new()
    root.add_child(parent)
    parent.position = at
    # Dimensioni dell'ostacolo originale 3 x 1.6 x 5.
    box(parent,Vector3(0,.8,0),Vector3(2.98,1.6,4.98),color)
    for x in [-1.5,1.5]:
        for j in range(15): box(parent,Vector3(x,.8,-2.4+j*.34),Vector3(.055,1.45,.075),"#89917a")
    for z in [-2.5,2.5]:
        for x in [-.73,.73]:
            box(parent,Vector3(x,.83,z),Vector3(1.43,1.5,.05),color)
            box(parent,Vector3(x,.83,z*1.015),Vector3(.05,1.4,.08),"#b0aa8a")
        for y in [.1,1.57]: box(parent,Vector3(0,y,z),Vector3(3,.1,.1),"#646e60")
    box(parent,Vector3(0,1.62,0),Vector3(3.05,.12,5.05),"#7e8a76")
    for j in range(5): box(parent,Vector3(-1.3+j*.65,1.7,.4),Vector3(.035,.04,4.9),"#9aa08a")

func timber_yard() -> void:
    for x in [-4,4]: container(Vector3(x,0,0),"#6f8274" if x < 0 else "#9b8060")
    # Atelier ouvert : toit incliné interrompu, établi et chevalets.
    for x in [-13,-7]:
        for z in [-10,-5]: beam(root,Vector3(x,0,z),Vector3(x,3.4,z),.18,"#8c7352","wood")
    for x in [-13,-10,-7]: beam(root,Vector3(x,3.4,-10),Vector3(x,3.0,-5),.14,"#84765a","wood")
    for i in range(8):
        var panel := box(root,Vector3(-12.6+i*.75,3.25,-7.5),Vector3(.7,.07,5.3),"#728275")
        panel.rotation.x = -.08
    workbench(Vector3(-11.5,0,-8.8))
    for at in [Vector3(-12,0,-1),Vector3(12,0,-1),Vector3(6,0,-12)]:
        pallet(at)
        crate(at+Vector3(0,.2,0))
        crate(at+Vector3(.2,1.1,.2),.8)
    for j in range(3):
        for i in range(5-j):
            var log := cylinder(root,Vector3(7+i*.45+j*.2,.3+j*.4,8),.23,3.5,"#9e815a",.2)
            log.rotation.x = PI*.5
    for z in [6.5,9.5]: beam(root,Vector3(6.5,.12,z),Vector3(9,.12,z),.2,"#665e45","wood")
    for x in [-.85,.85]: box(root,Vector3(x,.045,-1),Vector3(.1,.055,16),"#4f5e54")
    for z in range(-8,8,2): box(root,Vector3(0,.03,z),Vector3(2.1,.04,.18),"#8e7854","wood")

func utility_yard() -> void:
    box(root,Vector3(0,.8,-2),Vector3(4.98,1.6,2.98),"#6b827a")
    for x in [-1.8,0,1.8]:
        box(root,Vector3(x,.85,-.48),Vector3(1.55,1.3,.05),"#7a9187")
        for y in [.5,.65,.8,.95]: box(root,Vector3(x,y,-.43),Vector3(1.2,.04,.03),"#405850")
        box(root,Vector3(x,1.28,-.42),Vector3(.3,.12,.025),"#c2b782")
    box(root,Vector3(0,1.65,-2),Vector3(5.15,.12,3.15),"#4d695e")
    for x in [-5,5]:
        cylinder(root,Vector3(x,1.2,2),1.2,2.4,"#82948a")
        cylinder(root,Vector3(x,2.5,2),1.22,.35,"#768a7f",.5)
        for y in [.3,1.9]: cylinder(root,Vector3(x,y,2),1.25,.12,"#4f6b61")
        box(root,Vector3(x,.22,2),Vector3(2.5,.4,2.5),"#778577","stone")
        beam(root,Vector3(x,1.7,2),Vector3(x,1.7,-4),.16,"#a48e60")
    for at in [Vector3(-12,0,0),Vector3(12,0,0)]: workbench(at)
    for x in [-8,8]:
        for z in [6,7,8]: barrel(Vector3(x,0,z))
    for x in [-3.2,3.2]:
        for z in [-4.2,.1]: beam(root,Vector3(x,0,z),Vector3(x,3.7,z),.15,"#747e70")
    # Lame ajourées plutôt qu'un plafond opaque qui cache le personnage.
    for i in range(7): box(root,Vector3(-3+i,3.7,-2),Vector3(.12,.12,4.7),"#7d8d7b")
    for x in [-11,11]:
        box(root,Vector3(x,.075,-9),Vector3(2,.12,1.1),"#959b89","stone")
        for i in range(4): box(root,Vector3(x-.65+i*.43,.15,-9),Vector3(.08,.06,.9),"#58675c")

func survey_yard() -> void:
    for x in [-5,0,5]:
        for j in range(5):
            var plank := box(root,Vector3(x, .12+j*.18,0),Vector3(1.98,.16,2.98),"#9c8b64","wood")
            plank.rotation.y = float(j%2)*.025
        for z in [-.95,.95]: box(root,Vector3(x,.5,z),Vector3(2.02,.9,.09),"#596e62")
    for at in [Vector3(-10,0,-1),Vector3(10,0,0)]:
        workbench(at)
        box(root,at+Vector3(0,1.15,0),Vector3(.7,.35,.4),"#7c8f80")
        box(root,at+Vector3(0,1.2,.22),Vector3(.45,.2,.035),"#c3bb8d")
    for x in [-12,12]:
        beam(root,Vector3(x,0,-10),Vector3(x,3.4,-10),.16,"#7a806e")
        var panel := box(root,Vector3(x,2.65,-10),Vector3(2,.12,1.4),"#465e64")
        panel.rotation.x = -.4
        for i in range(4): box(panel,Vector3(-.75+i*.5,.075,0),Vector3(.025,.015,1.35),"#839a94")
    # Cable rolls and fabric shelters give the site a function without new mechanics.
    for at in [Vector3(-6,0,8),Vector3(5,0,-12)]:
        cylinder(root,at+Vector3(0,.4,0),.65,.7,"#766e50")
        for y in [.1,.8]: cylinder(root,at+Vector3(0,y,0),.85,.12,"#9a8a63")
    for z in [6,9]:
        for x in [9,12]: beam(root,Vector3(x,0,z),Vector3(x,2.5,z),.07,"#a0926f")
    var tarp := box(root,Vector3(10.5,2.55,7.5),Vector3(3.5,.04,3.6),"#8b8b68","wood")
    tarp.rotation.z = -.07

func pallet(at: Vector3) -> void:
    for i in range(5): box(root,at+Vector3(-.65+i*.32,.12,0),Vector3(.26,.16,1.5),"#a48b68","wood")
func crate(at: Vector3, scale_value: float = 1.0) -> void:
    box(root,at+Vector3(0,.4*scale_value,0),Vector3(1,.8,.85)*scale_value,"#9b825e","wood")
    for x in [-.35,.35]: box(root,at+Vector3(x*scale_value,.42*scale_value,0),Vector3(.08,.86,.9)*scale_value,"#5c6757")
func workbench(at: Vector3) -> void:
    box(root,at+Vector3(0,.9,0),Vector3(1.8,.12,.9),"#9d8b68","wood")
    for x in [-.7,.7]:
        for z in [-.3,.3]: beam(root,at+Vector3(x,0,z),at+Vector3(x,.85,z),.09,"#687165")
    box(root,at+Vector3(.4,1.05,0),Vector3(.35,.23,.3),"#6d8177")
    beam(root,at+Vector3(-.65,1,.1),at+Vector3(.1,1,.1),.06,"#b3aa83")
func barrel(at: Vector3) -> void:
    cylinder(root,at+Vector3(0,.45,0),.35,.9,"#8b8e72")
    for y in [.12,.77]: cylinder(root,at+Vector3(0,y,0),.365,.07,"#526a5d")
    cylinder(root,at+Vector3(.15,.92,.05),.07,.03,"#b4ac86")

func ground_cover(area: int) -> void:
    # Instancing grouped by shared geometry/material: large density, bounded draw calls.
    for i in range(26):
        var at := Vector3(rng.randf_range(-15,15),.033,rng.randf_range(-13,13))
        if absf(at.x) > 3 and clearance(at) > 2.8:
            patch(at,Vector2(rng.randf_range(1,2.8),rng.randf_range(.8,2.3)),["#69734f","#737b50","#6b7555"][i%3],i*71)
    for i in range(2200):
        var at := Vector3(rng.randf_range(-16,16),.04,rng.randf_range(-14,14))
        if absf(at.x) < 2.0 or clearance(at) < 2.1: continue
        var clustered := sin(at.x*.6)*cos(at.z*.42)
        if clustered < .15 and absf(at.x) < 13.5: continue
        var shape := foliage_mesh()
        var size := Vector3(rng.randf_range(.25,.75),rng.randf_range(.15,.45),rng.randf_range(.25,.75))
        instance_detail("moss%d" % (i%3),shape,at,size,["#626e43","#7c8250","#4d6547"][i%3])
        if i%3 == 0:
            var grass := foliage_mesh()
            instance_detail("grass%d" % (i%2),grass,at+Vector3(0,.2,0),Vector3.ONE,["#9a9765","#79834e"][i%2])
        if i%53 == 0:
            rock(root,at+Vector3(0,.1,0),Vector3(.65,.35,.45),"#91917a")
    for side in [-1,1]:
        for j in range(9):
            var at := Vector3(side*rng.randf_range(14.5,16),.25,-12+j*3)
            rock(root,at,Vector3(1.2,.7,1.0),["#5f704c","#798156","#6a7b52"][area])
func instance_detail(key: String, shape: Mesh, at: Vector3, size: Vector3, color: String) -> void:
    if not batches.has(key):
        var leaf_material := material(color,"earth").duplicate() as StandardMaterial3D
        leaf_material.vertex_color_use_as_albedo = true
        leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
        batches[key] = {"shape":shape,"material":leaf_material,"transforms":[]}
    var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(size)
    batches[key].transforms.append(Transform3D(basis,at))
func flush_batches() -> void:
    for key in batches:
        var data: Dictionary = batches[key]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = data.shape
        multi.instance_count = data.transforms.size()
        for i in range(multi.instance_count): multi.set_instance_transform(i,data.transforms[i])
        var node := MultiMeshInstance3D.new()
        node.name = "Vegetazione_"+key
        node.multimesh = multi
        node.material_override = data.material
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(node)
    batches.clear()
func clearance(at: Vector3) -> float:
    var distance := INF
    for goal in [Vector3(0,0,11),Vector3(-10,0,5),Vector3(10,0,-6),Vector3(0,0,-10),Vector3(-10,0,-7),Vector3(10,0,6)]: distance = minf(distance,Vector2(at.x-goal.x,at.z-goal.z).length())
    return distance
func entrance_sign() -> void:
    for x in [-1.7,1.7]:
        beam(root,Vector3(x,0,12),Vector3(x,1.4,12),.12,"#9a8862","wood")
        box(root,Vector3(x,1.2,12),Vector3(.25,.08,.25),"#d1b377")
    for i in range(5): box(root,Vector3(-1+i*.5,.025,11.5),Vector3(.4,.04,1.4),"#9f9473","wood")

func bake_small_props() -> void:
    var groups := {}
    for child in root.find_children("*","MeshInstance3D",true,false):
        var node := child as MeshInstance3D
        if node.get_meta("ground_surface",false): continue
        var relative: Transform3D = root.global_transform.affine_inverse()*node.global_transform
        var bounds: AABB = relative*node.get_aabb()
        if bounds.end.y > 1.35: continue
        var key := "%d:%d:%d" % [node.material_override.get_instance_id(),floori(relative.origin.x/6),floori(relative.origin.z/6)]
        if not groups.has(key):
            var st := SurfaceTool.new()
            st.begin(Mesh.PRIMITIVE_TRIANGLES)
            groups[key] = {"surface":st,"material":node.material_override,"nodes":[]}
        groups[key].surface.append_from(node.mesh,0,relative)
        groups[key].nodes.append(node)
    for key in groups:
        var group: Dictionary = groups[key]
        if group.nodes.size() < 2: continue
        var combined := MeshInstance3D.new()
        combined.name = "Dettagli_statici"
        combined.mesh = group.surface.commit()
        combined.material_override = group.material
        root.add_child(combined)
        for node in group.nodes: node.free()

func dress_interaction(item: Node3D, area: int, index: int) -> void:
    if index < 2 and area != 1:
        for child in item.get_children():
            if child is MeshInstance3D and child.name in ["Quadro","Leva"]: child.visible = false
    if index >= 2:
        # Cross bracing and feet distinguish salvage from the operating equipment.
        for x in [-.65,.65]: box(item,Vector3(x,.08,0),Vector3(.14,.15,1.2),"#667665")
        beam(item,Vector3(-.6,.2,.57),Vector3(.6,.85,.57),.07,"#806d4b","wood")
        box(item,Vector3(0,.65,.61),Vector3(.32,.2,.02),"#c1b58c","wood")
        return
    if area == 0:
        for x in [-.6,.6]: beam(item,Vector3(x,0,0),Vector3(x,1.15,0),.13,"#8d7954","wood")
        var reel := cylinder(item,Vector3(0,.6,0),.37,.85,"#6a796d")
        reel.rotation.z = PI*.5
        beam(item,Vector3(.5,.8,0),Vector3(.8,1.25,0),.08,"#b4a077")
        box(item,Vector3(0,.07,0),Vector3(1.4,.14,1.1),"#8b795c","wood")
    elif area == 1:
        box(item,Vector3(0,.95,.35),Vector3(.9,.7,.12),"#879a8d")
        for x in [-.23,.23]:
            var gauge := cylinder(item,Vector3(x,1.08,.44),.13,.035,"#d9d0a8")
            gauge.rotation.x = PI*.5
            beam(item,Vector3(x-.04,1.05,.47),Vector3(x+.04,1.14,.47),.015,"#4a5f54")
        for y in [.35,.47,.59]: box(item,Vector3(0,y,.35),Vector3(.58,.035,.035),"#3e5e50")
        cylinder(item,Vector3(-.35,1.55,0),.08,.17,"#c2ad73")
    else:
        for x in [-.5,.5]:
            beam(item,Vector3(x,0,.4),Vector3(0,1.2,0),.065,"#b6a778")
        beam(item,Vector3(0,0,-.55),Vector3(0,1.2,0),.065,"#b6a778")
        box(item,Vector3(0,1.25,0),Vector3(.65,.28,.55),"#859789")
        var lens := cylinder(item,Vector3(0,1.3,.35),.19,.2,"#405b5d")
        lens.rotation.x = PI*.5
        beam(item,Vector3(.25,1.3,0),Vector3(.25,2.0,0),.035,"#bab996")
        box(item,Vector3(0,.08,0),Vector3(1.15,.12,1.15),"#838773","stone")

func dress_machine(model: Node3D, area: int) -> Array:
    var parts: Array = []
    for child in model.get_children():
        if child is MeshInstance3D:
            child.material_override = material("#8c8a6d" if area == 0 else "#69877b","metal")
    if area == 0:
        for x in [-.85,.85]:
            for z in [-.55,.55]:
                var wheel := cylinder(model,Vector3(x,.25,z),.3,.16,"#495a50")
                wheel.rotation.z = PI*.5
                parts.append(wheel)
        parts.append(box(model,Vector3(0,1.42,0),Vector3(1.65,.12,1.35),"#a5926d","wood"))
        for z in [-.45,.45]: parts.append(box(model,Vector3(-.25,1.6,z),Vector3(.55,.3,.16),"#697b70"))
    elif area == 1:
        var coil := cylinder(model,Vector3(0,1.0,0),.58,1.6,"#8f9d8d")
        coil.rotation.z = PI*.5
        parts.append(coil)
        for x in [-.65,.65]:
            var end := cylinder(model,Vector3(x,1,0),.62,.12,"#526f64")
            end.rotation.z = PI*.5
            parts.append(end)
        for i in range(5): parts.append(box(model,Vector3(-.45+i*.23,1.2,.55),Vector3(.07,.6,.06),"#b0a67a"))
    else:
        var dish := cylinder(model,Vector3(0,1.65,0),.7,.22,"#c3bea2",.15)
        dish.rotation.z = .5
        parts.append(dish)
        parts.append(box(model,Vector3(0,1.12,.61),Vector3(.7,.35,.04),"#c3c5a0"))
    return parts

static var foliage: ArrayMesh
func foliage_mesh() -> ArrayMesh:
    if foliage != null: return foliage
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(7):
        var angle := i*2.399
        var side := Vector3(cos(angle),0,sin(angle))
        var a := side*.04
        var b := side*.16+Vector3.UP*.35
        var tip := side*.55+Vector3.UP*(.45+float(i%3)*.12)
        var across := Vector3(-side.z,0,side.x)*.09
        var vertices := [a-across,b-across,a+across,a+across,b-across,b+across,b-across,tip,b+across]
        for at in vertices:
            st.set_color(Color("#7c8d63").lerp(Color.WHITE,clampf(at.y,0,1)))
            st.set_uv(Vector2(at.x,at.y))
            st.add_vertex(at)
    st.generate_normals()
    foliage = st.commit()
    return foliage
