extends SceneTree
var failures: int = 0
func check(condition: bool, description: String) -> void:
    if not condition:
        failures += 1
        push_error(description)
func volume(node: Node) -> float:
    var total: float = 0
    if node is MeshInstance3D:
        var dimensions: Vector3 = node.mesh.get_aabb().size
        total += dimensions.x*dimensions.y*dimensions.z
    for child in node.get_children():
        total += volume(child)
    return total
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.process_mode = Node.PROCESS_MODE_DISABLED
    game.skip_save_on_exit = true
    game.stockade_built = true
    game._build_stockade()
    var components: Array = [game.cabin_visual,game.gate_visual,game.bench_visual]
    for wall in game.wall_segments:
        components.append(wall["durability"])
    var registered: Dictionary = {}
    var actual_boards: int = 0
    for item in game.fence_root.get_children():
        if item is MeshInstance3D and item.get_meta("visual_role","") in ["Asse","Punta"]:
            actual_boards += 1
    var bound_boards: int = 0
    for wall in game.wall_segments:
        for entry in wall["durability"].bound_meshes:
            var item: MeshInstance3D = entry["mesh"]
            if item.get_meta("visual_role","") in ["Asse","Punta"]:
                check(not registered.has(item.get_instance_id()),"Nessuna asse condivisa tra sezioni con HP diversi")
                registered[item.get_instance_id()] = true
                bound_boards += 1
    check(bound_boards == actual_boards and actual_boards > 100,"Tutte le assi e punte reali sono associate a una sezione")
    for component in components:
        var intact: Array[Transform3D] = []
        for entry in component.bound_meshes:
            intact.append(entry["mesh"].transform)
        component.set_health(component.max_hp*.7)
        var light_volume: float = 0
        for entry in component.bound_meshes:
            check(not entry["mesh"].visible and entry["variants"][0].visible,"La geometria integra e' sostituita in stato danneggiato")
            light_volume += volume(entry["variants"][0])
        check(light_volume > .01,"Variante danneggiata non vuota")
        component.set_health(component.max_hp*.2)
        var heavy_volume: float = 0
        for entry in component.bound_meshes:
            check(not entry["mesh"].visible and not entry["variants"][0].visible and entry["variants"][1].visible,"Stato grave distinto e senza geometria integra sovrapposta")
            heavy_volume += volume(entry["variants"][1])
        check(heavy_volume > 0 and heavy_volume < light_volume*.85,"Elementi realmente mancanti nello stadio grave")
        component.set_health(0)
        check(component.rubble.visible and volume(component.rubble) > .01,"Detriti di crollo presenti")
        for entry in component.bound_meshes:
            check(not entry["mesh"].visible and not entry["variants"][0].visible and not entry["variants"][1].visible,"A zero HP non rimangono elementi sospesi")
        component.set_health(component.max_hp)
        for index in range(component.bound_meshes.size()):
            var entry: Dictionary = component.bound_meshes[index]
            check(entry["mesh"].visible and entry["mesh"].transform.is_equal_approx(intact[index]),"Riparazione ripristina la mesh originale")
        check(not component.bar.visible,"Barre salute conservate")
    # Gli stadi estetici non modificano mai le collisioni funzionanti.
    game._sync_gate_collision(true)
    await physics_frame
    await physics_frame
    var collision_before: bool = game.gate_barrier.disabled
    game.gate_visual.set_health(1)
    check(game.gate_barrier.disabled == collision_before,"Nessuna modifica alle collisioni dagli stadi grafici")
    var sample := MeshInstance3D.new()
    sample.mesh = BoxMesh.new()
    sample.mesh.size = Vector3(1,2,.3)
    game.add_child(sample)
    var future = game._make_structure_visual(game,"future",100,Vector3(0,3,0))
    future.bind_meshes([sample])
    future.set_health(20)
    check(not sample.visible and volume(future.bound_meshes[0]["variants"][1]) > 0,"Fallback geometrico per nuove costruzioni")
    game.queue_free()
    await process_frame
    print("Geometria strutture: %d errori" % failures)
    quit(1 if failures else 0)
