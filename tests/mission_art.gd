extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",ProjectSettings.globalize_path("user://art-tests"))
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.set_process(false)
    game.hero.set_physics_process(false)
    game.skip_save_on_exit = true
    var f = game.frontier
    f.set_process(false)
    game.stockade_built = true
    game.base_level = 2
    game._build_stockade()
    f.completed = [true,true,true]
    f.tool = true
    for key in ["workshop","generator"]: f._create_station(key,160)
    for area in range(3):
        var place: Node3D = f.models[area]
        var art = place.get_node("Diorama_spedizione")
        check(art.find_children("*","CollisionObject3D",true,false).is_empty(),"Allestimenti senza ostacoli fisici aggiunti")
        var solid_count := 0
        for child in place.get_children():
            if child is StaticBody3D: solid_count += 1
        check(solid_count == [7,6,8][area],"Conservati pavimento, confini e coperture originali")
        var instances := 0
        for batch in art.find_children("*","MultiMeshInstance3D",true,false):
            instances += batch.multimesh.instance_count
        check(instances >= 100,"Vegetazione raggruppata per contenere il costo di rendering")
        check(art.find_children("*","MeshInstance3D",true,false).size() < 800,"Budget geometrico statico limitato per area")
        var terrain: MeshInstance3D = art.get_node("Terreno_continuo")
        check(not game.occluders.has(terrain),"Il terreno non svanisce con la trasparenza degli ostacoli")
        check(terrain.material_override.albedo_texture.get_image().has_mipmaps(),"Materiali filtrati anche a distanza")
        game.hero.position = f.board.position
        f.enter_area(area)
        f._process(0)
        check(game.camera.environment == f.area_environments[area],"Atmosfera locale attiva soltanto nella spedizione")
        for yaw in [0,PI*.5,PI,PI*1.5]:
            game.camera_yaw_current = yaw
            game._update_camera(1)
            game._update_occlusion(1)
        f.leave_area(false)
        f._process(0)
        check(game.camera.environment == null,"Atmosfera originale della base ripristinata al rientro")
    game.queue_free()
    await process_frame
    print("Allestimenti, collisioni e isolamento grafico: %d errori" % failures)
    quit(1 if failures else 0)
