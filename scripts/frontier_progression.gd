extends Node3D
## Progressione di spedizioni e postazioni; nessun reddito passivo o attesa obbligata.
const STATION_HP := 160.0
const STATION_INFO := {
    "workshop":{"title":"Officina","use":"attrezzi e kit","at":Vector3(-4.7,0,-3.8),"wood":20,"parts":2},
    "storage":{"title":"Magazzino","use":"carico da 3 a 5","at":Vector3(4.7,0,-5.6),"wood":20,"parts":2},
    "generator":{"title":"Generatore","use":"spedizione attrezzata","at":Vector3(4.7,0,-.4),"wood":25,"parts":3}
}
const AREA_NAMES := ["Recupera attrezzatura utile","Stabilizza l'alimentazione","Collega la rete di allerta"]
var game
var ops
var stations: Dictionary = {}
var parts := 0
var cells := 0
var tool := false
var kits := 0
var completed: Array = [false,false,false]
var visits: Array = [0,0,0]
var active_area := -1
var used: Array = []
var switches: Array = [false,false]
var bag_parts := 0
var bag_cells := 0
var bag_slots := 0
var primary := false
var power_mode := -1
var notes: Array = []
var models: Array[Node3D] = []
var point_models: Array = []
var menu: PopupPanel
var menu_body: VBoxContainer
var hint: Label3D
var board: Node3D
var note_dialog: AcceptDialog
var note_open := false
var note_previous_pause := false
var objective_marker: Node3D
var objective_label: Label3D

func configure(world) -> void:
    game = world
    board = Node3D.new()
    add_child(board)
    board.position = Vector3(3.1,0,3.0)
    game._box(board,"Palo_bacheca",Vector3(0,.8,0),Vector3(.12,1.6,.12),"#735139")
    game._box(board,"Bacheca",Vector3(0,1.5,0),Vector3(1.5,.8,.1),"#976c42")
    for i in range(3): game._box(board,"Mappa",Vector3((i-1)*.4,1.5,.07),Vector3(.3,.5,.035),"#d6c69b")
    var label := _label3(board,Vector3(0,2.2,0),"G: SPEDIZIONI E POSTAZIONI")
    label.font_size = 25
    menu = PopupPanel.new()
    menu.title = "Spedizioni e base"
    menu.size = Vector2i(610,490)
    var style = game._make_panel_style()
    style.bg_color = Color("#182b23")
    menu.add_theme_stylebox_override("panel",style)
    add_child(menu)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(580,460)
    menu.add_child(scroll)
    menu_body = VBoxContainer.new()
    menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(menu_body)
    hint = _label3(self,Vector3.ZERO,"")
    hint.no_depth_test = true
    note_dialog = AcceptDialog.new()
    note_dialog.title = "Appunto raccolto"
    note_dialog.exclusive = true
    note_dialog.ok_button_text = "Chiudi e riprendi"
    note_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note_dialog.get_label().custom_minimum_size = Vector2(580,160)
    note_dialog.get_label().add_theme_font_size_override("font_size",18)
    note_dialog.confirmed.connect(close_note)
    note_dialog.canceled.connect(close_note)
    add_child(note_dialog)
    objective_marker = Node3D.new()
    add_child(objective_marker)
    game._cone(objective_marker,"Indicatore_obiettivo",Vector3(0,.05,0),1.05,.06,"#edc35c",1.05)
    objective_label = _label3(objective_marker,Vector3(0,2.7,0),"OBIETTIVO [F]")
    objective_label.modulate = Color("#ffe195")
    objective_label.no_depth_test = true
    objective_marker.visible = false
    for area in range(3): _create_area(area)
    ops = preload("res://scripts/mission_operations.gd").new()
    add_child(ops)
    ops.configure(self)

func _label3(parent: Node3D, at: Vector3, title: String) -> Label3D:
    var label := Label3D.new()
    label.text = title
    label.position = at
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 32
    label.pixel_size = .012
    label.outline_size = 6
    parent.add_child(label)
    return label

func center(area: int) -> Vector3:
    return Vector3(66+float(area)*44,0,0)
func entrance(area: int) -> Vector3:
    return center(area)+Vector3(0,.14,11)
func point(area: int, index: int) -> Vector3:
    return center(area)+[Vector3(-10,0,5),Vector3(10,0,-6),Vector3(0,0,-10),Vector3(-10,0,-7),Vector3(10,0,6)][index]
func _solid(parent: Node3D, at: Vector3, size: Vector3, color: String) -> void:
    var body := StaticBody3D.new()
    parent.add_child(body)
    body.position = at
    game._box(body,"Elemento",Vector3(0,size.y*.5,0),size,color)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    col.position.y = size.y*.5
    col.shape = shape
    body.add_child(col)
func _create_area(area: int) -> void:
    var place := Node3D.new()
    place.position = center(area)
    add_child(place)
    models.append(place)
    _solid(place,Vector3(0,-.4,0),Vector3(34,.4,30),["#687b61","#6d7778","#7d7961"][area])
    for x in [-17,17]: _solid(place,Vector3(x,0,0),Vector3(.5,1.2,30),"#58655b")
    for z in [-15,15]: _solid(place,Vector3(0,0,z),Vector3(34,1.2,.5),"#58655b")
    # Coperture differenti, con spazio libero su entrambi i lati.
    if area == 0:
        for x in [-4,4]: _solid(place,Vector3(x,0,0),Vector3(3,1.6,5),"#758779")
    elif area == 1:
        _solid(place,Vector3(0,0,-2),Vector3(5,1.6,3),"#607878")
        for x in [-5,5]:
            var tank = game._cone(place,"Serbatoio",Vector3(x,1.2,2),1.2,2.4,"#828d85",1.2)
            tank.rotation.y = .2
    else:
        for x in [-5,0,5]: _solid(place,Vector3(x,0,0),Vector3(2,1.0,3),"#88856a")
        for i in range(4): game._box(place,"Trave",Vector3(-5+i*3,.3,-4),Vector3(1.6,.35,.45),"#b1a077",.15)
    _dress_area(place,area)
    _label3(place,Vector3(0,1.1,12),"F: RIENTRA ALLA BASE CON IL CARICO")
    var items: Array = []
    for index in range(5):
        var item := Node3D.new()
        item.position = point(area,index)-center(area)
        place.add_child(item)
        if index < 2:
            game._box(item,"Quadro",Vector3(0,.7,0),Vector3(.8,1.4,.65),"#617d80")
            game._box(item,"Leva",Vector3(0,1.0,.4),Vector3(.13,.4,.15),"#e3b566")
        else:
            game._box(item,"Contenitore",Vector3(0,.5,0),Vector3(1.4,1.0,1.1),"#ad8958")
            game._box(item,"Coperchio",Vector3(0,1.07,0),Vector3(1.5,.12,1.2),"#d1ae72")
            for x in [-.46,.46]: game._box(item,"Fascia",Vector3(x,.55,.02),Vector3(.1,1.14,1.18),"#776849")
        _label3(item,Vector3(0,1.9,0),("%d: %s [F]" % [index+1,["ISPEZIONA", "RIPRISTINA", "RILEVA"][area]]) if index < 2 else ("3: CARICO PRINCIPALE [F]" if index == 2 else "FACOLTATIVO [F]"))
        items.append(item)
    point_models.append(items)
    game._register_occluders(place)
    place.visible = false

func working(key: String) -> bool:
    return stations.has(key) and float(stations[key]["hp"]) > 0
func capacity() -> int:
    return 5 if working("storage") else 3
func unlocked(area: int) -> bool:
    if not game.stockade_built or game.base_level < 2: return false
    if area == 0: return true
    if area == 1: return completed[0] and working("workshop") and tool
    return completed[1] and working("workshop") and working("generator")
func _clear_menu(title: String) -> void:
    for child in menu_body.get_children():
        menu_body.remove_child(child)
        child.queue_free()
    var label := Label.new()
    label.text = title
    label.add_theme_font_size_override("font_size",17)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size.x = 570
    menu_body.add_child(label)
func _option(title: String, callback: Callable, disabled: bool = false) -> void:
    var button := Button.new()
    button.text = title
    button.add_theme_font_size_override("font_size",16)
    button.custom_minimum_size.y = 36
    button.disabled = disabled
    button.pressed.connect(callback)
    menu_body.add_child(button)
func open_menu() -> void:
    if game.paused: return
    if active_area >= 0:
        show_mission_help()
        return
    if game.hero.position.distance_to(board.position) > 6:
        game.show_message("G vicino alla bacheca nel cortile.",3)
        return
    game.hero.clear_mouse_destination()
    _clear_menu("SPEDIZIONI E POSTAZIONI\nComponenti %d | Celle %d | Kit %d | Carico %d\n%s" % [parts,cells,kits,capacity(),progress_text()])
    for area in range(3):
        var index: int = area
        var requirement: String = ["cortile ampliato","officina + attrezzi da campo","generatore e officina funzionanti"][area]
        _option(("Missione: " if not ops.results[area] else "Rivisita: ")+AREA_NAMES[area]+(" | "+requirement if not unlocked(area) else ""),func(): show_brief(index),not unlocked(area))
    for key in STATION_INFO:
        var id: String = key
        var info: Dictionary = STATION_INFO[key]
        if not stations.has(key):
            _option("%s (%s) | %d legno, %d componenti%s" % [info.title,info.use,info.wood,info.parts,", 1 cella" if key == "generator" else ""],func(): build_station(id),not can_build(id))
        else:
            var cost: int = game.repair_cost("station:"+key)
            _option("%s: %d/160 HP | ripara 100%%: %d legno" % [info.title,ceili(stations[key].hp),cost],func():
                game.manual_target = "station:"+id
                game._repair_selected("station:"+id)
                open_menu(),cost == 0)
    _option("Attrezzi da campo | 8 legno + 1 componente",craft_tool,tool or not working("workshop") or parts < 1 or game.wood < 8)
    _option("Kit da campo (H: usa) | %d legno + 1 componente" % kit_cost(),craft_kit,not working("workshop") or kits >= 3 or parts < 1 or game.wood < kit_cost())
    if not notes.is_empty(): _option("Appunti raccolti",show_notes)
    _option("Chiudi",func(): menu.hide())
    _show_menu()

func can_build(key: String) -> bool:
    if not STATION_INFO.has(key) or stations.has(key) or game.base_level < 2 or not completed[0]: return false
    var info: Dictionary = STATION_INFO[key]
    return game.wood >= info.wood and parts >= info.parts and (key != "generator" or (completed[1] and cells >= 1 and working("workshop")))
func build_station(key: String) -> void:
    if game.paused or active_area >= 0 or game.hero.position.distance_to(board.position) > 6 or not can_build(key): return
    var info: Dictionary = STATION_INFO[key]
    game.wood -= int(info.wood)
    parts -= int(info.parts)
    if key == "generator": cells -= 1
    _create_station(key,STATION_HP)
    game.show_message("%s costruito e operativo." % info.title,3)
    game._save_progress()
    open_menu()
func _create_station(key: String, hp: float) -> void:
    var info: Dictionary = STATION_INFO[key]
    var node := Node3D.new()
    node.position = info.at
    add_child(node)
    var meshes: Array = []
    if key == "storage":
        meshes.append(game._box(node,"Scaffale",Vector3(0,.7,0),Vector3(1.6,.15,1.0),"#9c744b"))
        meshes.append(game._box(node,"Tetto",Vector3(0,1.9,0),Vector3(1.9,.18,1.35),"#657b69"))
    elif key == "workshop":
        meshes.append(game._box(node,"Piano",Vector3(0,.9,0),Vector3(1.6,.18,1.0),"#a08558"))
        meshes.append(game._box(node,"Morsa",Vector3(.4,1.15,0),Vector3(.4,.4,.5),"#6f8282"))
    else:
        meshes.append(game._box(node,"Telaio",Vector3(0,.6,0),Vector3(1.4,1.1,.9),"#637f79"))
        meshes.append(game._box(node,"Scarico",Vector3(.5,1.35,0),Vector3(.16,.7,.16),"#7c8984"))
    for x in [-.7,.7]:
        for z in [-.4,.4]: meshes.append(game._box(node,"Palo",Vector3(x,.65,z),Vector3(.14,1.3,.14),"#735238"))
    if key == "workshop" and ops.results[0]:
        meshes.append(game._box(node,"Utensiliera",Vector3(0,1.5,-.42),Vector3(1.4,.7,.1),"#8a7754"))
        for i in range(3): meshes.append(game._box(node,"Attrezzo_recuperato",Vector3(-.45+i*.45,1.5,-.32),Vector3(.12,.45,.12),"#b1b79b"))
    if key == "generator" and ops.results[1]:
        meshes.append(game._box(node,"Accumulatore",Vector3(.52,.95,.2),Vector3(.55,.8,.5),"#c2af68"))
    var visual = game._make_structure_visual(node,"station",STATION_HP,Vector3(0,2.5,0))
    visual.bind_meshes(meshes)
    var body := StaticBody3D.new()
    node.add_child(body)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.6,1.6,1.0)
    col.shape = shape
    col.position.y = .8
    body.add_child(col)
    var station_title: String = info.title
    if key == "workshop" and ops.results[0]: station_title = "Officina attrezzata"
    if key == "generator" and ops.results[1]: station_title = "Generatore stabilizzato"
    _label3(node,Vector3(0,2,0),station_title)
    stations[key] = {"node":node,"hp":hp,"visual":visual,"collider":col}
    sync_stations()
    game._register_occluders(node)
func sync_stations() -> void:
    for key in stations:
        var station: Dictionary = stations[key]
        station.visual.set_health(float(station.hp))
        station.collider.set_deferred("disabled",station.hp <= 0)
func has_damage() -> bool:
    for key in stations:
        if stations[key].hp < STATION_HP: return true
    return false
func restore_station(key: String) -> void:
    stations[key].hp = STATION_HP
    sync_stations()
func restore_all() -> void:
    for key in stations: stations[key].hp = STATION_HP
    sync_stations()
func attack_near_station(at: Vector3, amount: float) -> bool:
    for key in stations:
        var station: Dictionary = stations[key]
        if station.hp > 0 and at.distance_to(station.node.global_position) < 2.3:
            station.hp = maxf(0,station.hp-amount*.36)
            game.alerts.attacked(str(STATION_INFO[key].title),station.hp <= 0)
            sync_stations()
            return true
    return false
func craft_tool() -> void:
    if game.paused or active_area >= 0 or game.hero.position.distance_to(board.position) > 6 or tool or not working("workshop") or parts < 1 or game.wood < 8: return
    game.wood -= 8
    parts -= 1
    tool = true
    game._save_progress()
    open_menu()
func craft_kit() -> void:
    if game.paused or active_area >= 0 or game.hero.position.distance_to(board.position) > 6 or not working("workshop") or kits >= 3 or parts < 1 or game.wood < kit_cost(): return
    game.wood -= kit_cost()
    parts -= 1
    kits += 1
    game._save_progress()
    open_menu()
func use_kit() -> void:
    if game.paused or kits <= 0 or game.hero.hp >= 100: return
    kits -= 1
    game.hero.hp = minf(100,game.hero.hp+65)
    game.hero._update_health_bar()
    game.show_message("Kit utilizzato: salute recuperata.",2)
    game._save_progress()

func enter_area(area: int) -> void:
    if area < 0 or area > 2 or game.paused or active_area >= 0 or not unlocked(area) or game.hero.position.distance_to(board.position) > 6: return
    if game.expedition.active or game.salvage.carried > 0:
        game.show_message("Concludi prima il trasporto in corso.",3)
        return
    active_area = area
    visits[area] += 1
    used.clear()
    switches = [false,false]
    bag_parts = 0
    bag_cells = 0
    bag_slots = 0
    primary = false
    power_mode = -1
    ops.reset()
    models[area].visible = true
    _sync_points()
    game.hero.clear_mouse_destination()
    game.hero.position = entrance(area)
    game.camera_focus = game.hero.position+Vector3.UP
    game.hero.velocity = Vector3.ZERO
    menu.hide()
    _spawn_group(center(area)+Vector3(-8,0,0),2)
    game.show_message(["Libera i due fermi, poi avvia il verricello: accompagna l’apparato e proteggilo. G: scopo e istruzioni.","Prepara i due quadri, avvia la carica e proteggi l’apparato. G: scopo e istruzioni.","Rileva i due punti, attiva la rete e collega entrambi i sensori. G: scopo e istruzioni."][area],6)
    game._save_progress()
func interact() -> bool:
    if active_area < 0 or game.paused: return false
    if not ops.legacy_run:
        if ops.phase in [2,3] and not primary and game.hero.position.distance_to(ops.pickup_position()) <= 2.6:
            if ops.phase == 3: ops.start()
            else: take_loot(2,false)
            return true
        if ops.phase == 1 and active_area == 1 and ops.fault and game.hero.position.distance_to(point(1,1)) <= 2.6:
            ops.repair_fault()
            return true
        if ops.phase == 1 and active_area == 2:
            for beacon in [3,4]:
                if game.hero.position.distance_to(point(2,beacon)) <= 2.6:
                    ops.install_beacon(beacon)
                    return true
    if game.hero.position.distance_to(entrance(active_area)) < 2.8:
        leave_area(true)
        return true
    for index in range(5):
        if used.has(index) or game.hero.position.distance_to(point(active_area,index)) > 2.6: continue
        if active_area == 2 and game.closest_enemy(game.hero.position,4.0) != null:
            game.show_message("Allontana gli zombie prima di effettuare il rilevamento.",3)
            return true
        if active_area == 1 and index == 0:
            _clear_menu("ALIMENTAZIONE DEL RECUPERO\nLa modalita silenziosa richiama meno zombie. L'argano recupera piu componenti, ma il rumore li attira.")
            _option("Alimentazione silenziosa",func(): set_power_mode(false))
            _option("Argano: +2 componenti al carico principale, rischio",func(): set_power_mode(true))
            _option("Decidi dopo",func(): menu.hide())
            _show_menu()
            return true
        if index < 2:
            switches[index] = true
            used.append(index)
            _spawn_group(point(active_area,index)+Vector3(3,0,1),1)
            game.show_message("Punti preparati: %d/2." % (int(switches[0])+int(switches[1])),3)
            _sync_points()
            game._save_progress()
        elif index == 2:
            if not switches[0] or not switches[1]:
                game.show_message("Prepara entrambi i punti prima del recupero principale.",3)
            elif not ops.legacy_run and not ops.ready_to_collect(): ops.start()
            else: take_loot(index,false)
        else:
            if active_area == 2 and not ops.legacy_run:
                game.show_message("Questi sono sensori: attiva prima l'apparato centrale.",3)
                return true
            _clear_menu("CARICO FACOLTATIVO\nLibero: %d/%d. Il recupero pesante attira zombie; puoi rientrare in ogni momento." % [maxi(0,capacity()-bag_slots),capacity()])
            var chosen: int = index
            _option("Recupero leggero | 1 posto, 1 componente",func(): take_loot(chosen,false),bag_slots+1 > capacity())
            _option("Smontaggio completo | 2 posti, 3 componenti, rischio",func(): take_loot(chosen,true),bag_slots+2 > capacity())
            _option("Lascia qui",func(): menu.hide())
            _show_menu()
        return true
    game.show_message("F vicino a un quadro, un carico o al punto di rientro.",2)
    return true
func take_loot(index: int, heavy: bool) -> void:
    if active_area < 0 or game.paused or index < 2 or index > 4 or used.has(index): return
    var location: Vector3 = ops.pickup_position() if index == 2 else point(active_area,index)
    if game.hero.position.distance_to(location) > 2.6: return
    if index == 2 and (not switches[0] or not switches[1]): return
    if index == 2 and not ops.ready_to_collect():
        game.show_message("Porta prima a termine l'operazione indicata.",3)
        return
    var slots := (0 if not ops.legacy_run else 1) if index == 2 else (2 if heavy else 1)
    if bag_slots+slots > capacity():
        game.show_message("Carico pieno. Rientra o lascia il materiale facoltativo.",3)
        return
    var new_note_index := -1
    used.append(index)
    bag_slots += slots
    bag_parts += 2 if index == 2 else (3 if heavy else 1)
    if index == 2:
        if active_area == 1 and power_mode == 1: bag_parts += 2
        primary = true
        if active_area == 1: bag_cells += 1
        if not notes.has(active_area): notes.append(active_area)
        new_note_index = active_area
    if heavy: _spawn_group(point(active_area,index)+Vector3(2,0,-4.5),2)
    menu.hide()
    _sync_points()
    game.show_message("Carico %d/%d. Puoi rientrare o cercare altro materiale." % [bag_slots,capacity()],3)
    game._save_progress()
    if new_note_index >= 0: show_collected_note(new_note_index)
func _spawn_group(at: Vector3, count: int) -> void:
    for i in range(count):
        if game.enemies.size() < 32: game._spawn_enemy(at+Vector3(i*1.2,.13,0),"normal",false)
func _sync_points() -> void:
    for area in range(3):
        for i in range(5): point_models[area][i].visible = active_area != area or not used.has(i)
    if is_instance_valid(ops): ops.sync_visuals()
func leave_area(deliver: bool) -> void:
    if active_area < 0: return
    var old_area: int = active_area
    if deliver:
        parts += bag_parts
        cells += bag_cells
        if primary:
            if not completed[old_area]:
                game.wood += 35
                game.coins += 20
            completed[old_area] = true
            if not ops.legacy_run: apply_mission_result(old_area)
        if not primary or ops.legacy_run:
            game.show_message("Rientro completato: +%d componenti, +%d celle. Carico al sicuro." % [bag_parts,bag_cells],5)
    else:
        game.show_message("Spedizione interrotta: carico non consegnato perso. Progetti e base conservati.",4)
    models[old_area].visible = false
    for enemy in game.enemies:
        if is_instance_valid(enemy) and enemy.position.x > 40: enemy.queue_free()
    active_area = -1
    ops.reset()
    bag_slots = 0
    bag_parts = 0
    bag_cells = 0
    primary = false
    used.clear()
    game.hero.clear_mouse_destination()
    game.hero.velocity = Vector3.ZERO
    game.hero.position = Vector3(0,.15,game.gate_front_z()+1)
    game.camera_focus = game.hero.position+Vector3.UP
    menu.hide()
    game._save_progress()
func clamp_hero(at: Vector3) -> Vector3:
    if active_area < 0: return Vector3(clampf(at.x,-20,20),at.y,clampf(at.z,-20,20))
    var c := center(active_area)
    return Vector3(clampf(at.x,c.x-16,c.x+16),at.y,clampf(at.z,-14,14))
func _process(_delta: float) -> void:
    if game == null: return
    objective_marker.visible = active_area >= 0
    if game.paused: return
    hint.visible = active_area >= 0
    if active_area >= 0:
        hint.position = game.hero.position+Vector3(0,2.7,0)
        objective_marker.position = objective_position()
        objective_label.text = "RIENTRO [F]" if primary else (ops.target_caption() if not ops.legacy_run and ops.phase > 0 else "OBIETTIVO %d [F]" % (objective_index()+1))
        if not ops.legacy_run and ops.phase == 1 and (active_area == 0 or (active_area == 1 and not ops.fault)):
            hint.text = "Resta vicino e proteggi l'apparato"
        else:
            hint.text = "F: interagisci" if game.hero.position.distance_to(objective_position()) < 2.6 else "Raggiungi il cerchio sotto il bersaglio"
func progress_text() -> String:
    if active_area >= 0: return mission_instruction()
    var count := int(ops.results[0])+int(ops.results[1])+int(ops.results[2])
    if count == 3: return "OPERAZIONI COMPLETATE: 3/3 | benefici attivi al rifugio"
    if game.base_level < 2: return "G alla bacheca: missioni dopo l'ampliamento"
    if not ops.results[0]: return "G alla bacheca: missione per attrezzare l'officina"
    if not working("workshop"): return "Ripara l'officina per proseguire"
    if not tool: return "G alla bacheca: prepara gli attrezzi da campo"
    if not ops.results[1]: return "G alla bacheca: missione per stabilizzare l'alimentazione"
    if not working("generator"): return "Ripara il generatore per proseguire"
    return "G alla bacheca: missione per collegare la rete di allerta"
func show_notes() -> void:
    _clear_menu("APPUNTI DI CAMPO")
    var entries: Array = load("res://resources/field_entries.gd").new().entries
    for index in notes:
        var label := Label.new()
        label.text = entries[int(index)]
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.custom_minimum_size.x = 560
        menu_body.add_child(label)
    _option("Torna",open_menu)
func save_data() -> Dictionary:
    var buildings := {}
    for key in stations: buildings[key] = stations[key].hp
    var remote_enemies: Array = []
    for enemy in game.enemies:
        if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.defeated and enemy.position.x > 40:
            remote_enemies.append({"x":enemy.position.x,"z":enemy.position.z,"hp":enemy.hp,"variant":enemy.variant})
    return {"parts":parts,"cells":cells,"tool":tool,"kits":kits,"completed":completed,"visits":visits,"stations":buildings,"active_area":active_area,"used":used,"switches":switches,"bag_parts":bag_parts,"bag_cells":bag_cells,"bag_slots":bag_slots,"primary":primary,"power_mode":power_mode,"notes":notes,"enemies":remote_enemies,"mission_ops":ops.save_data()}
func load_data(data) -> void:
    if not data is Dictionary: return
    parts = maxi(0,int(data.get("parts",0)))
    cells = maxi(0,int(data.get("cells",0)))
    tool = bool(data.get("tool",false))
    kits = clampi(int(data.get("kits",0)),0,3)
    var saved_completed = data.get("completed",[])
    var saved_visits = data.get("visits",[])
    for i in range(3):
        completed[i] = bool(saved_completed[i]) if saved_completed is Array and saved_completed.size() > i else false
        visits[i] = maxi(0,int(saved_visits[i])) if saved_visits is Array and saved_visits.size() > i else 0
    var saved_ops = data.get("mission_ops",{})
    var saved_results = saved_ops.get("results",[]) if saved_ops is Dictionary else []
    for i in range(3): ops.results[i] = bool(saved_results[i]) if saved_results is Array and saved_results.size() > i else false
    for key in stations: stations[key].node.queue_free()
    stations.clear()
    var saved_stations = data.get("stations",{})
    if saved_stations is Dictionary:
        for key in STATION_INFO:
            if saved_stations.has(key): _create_station(key,clampf(float(saved_stations[key]),0,STATION_HP))
    active_area = clampi(int(data.get("active_area",-1)),-1,2)
    used.clear()
    for index in data.get("used",[]):
        if int(index) in range(5) and not used.has(int(index)): used.append(int(index))
    var saved_switches = data.get("switches",[false,false])
    switches = [bool(saved_switches[0]),bool(saved_switches[1])] if saved_switches is Array and saved_switches.size() == 2 else [false,false]
    bag_parts = clampi(int(data.get("bag_parts",0)),0,10)
    bag_cells = clampi(int(data.get("bag_cells",0)),0,1)
    bag_slots = clampi(int(data.get("bag_slots",0)),0,5)
    primary = bool(data.get("primary",false))
    power_mode = clampi(int(data.get("power_mode",-1)),-1,1)
    notes.clear()
    for index in data.get("notes",[]):
        if int(index) in range(3) and not notes.has(int(index)): notes.append(int(index))
    for area in range(3): models[area].visible = active_area == area
    for enemy in game.enemies:
        if is_instance_valid(enemy) and enemy.position.x > 40: enemy.queue_free()
    if active_area >= 0:
        for saved in data.get("enemies",[]):
            if game.enemies.size() < 32:
                var at := Vector3(clampf(float(saved.get("x",center(active_area).x)),center(active_area).x-15,center(active_area).x+15),.13,clampf(float(saved.get("z",0)),-13,13))
                game._spawn_enemy(at,"normal",false)
                game.enemies.back().hp = clampf(float(saved.get("hp",48)),1,48)
    ops.load_data(data.get("mission_ops",{}),active_area >= 0)
    _sync_points()

func set_power_mode(heavy: bool) -> void:
    if game.paused or active_area != 1 or used.has(0) or game.hero.position.distance_to(point(1,0)) > 2.6: return
    power_mode = 1 if heavy else 0
    switches[0] = true
    used.append(0)
    if heavy: _spawn_group(point(1,0)+Vector3(3,0,2),2)
    menu.hide()
    _sync_points()
    game.show_message("Alimentazione impostata. Raggiungi il secondo quadro.",3)
    game._save_progress()

func station_defense_target(at: Vector3) -> Vector3:
    var closest: Vector3 = Vector3.INF
    var distance := 3.5
    for key in stations:
        var station: Dictionary = stations[key]
        if station.hp <= 0: continue
        var delta: Vector3 = at-station.node.global_position
        delta.y = 0
        if delta.length() < distance:
            distance = delta.length()
            closest = station.node.global_position+delta.normalized()*1.15
    return closest

func _dress_area(place: Node3D, area: int) -> void:
    game._box(place,"Margine_terreno",Vector3(0,-.3,0),Vector3(70,.1,65),"#597356")
    for side in [-1,1]:
        for z in [-18,-11,0,11,18]:
            var tree := Node3D.new()
            place.add_child(tree)
            tree.position = Vector3(side*19,0,z)
            game._cone(tree,"Tronco",Vector3(0,1,0),.25,2,"#765339",.18)
            for i in range(3): game._cone(tree,"Chioma",Vector3(0,2.1+i*.8,0),1.5-i*.3,2.1,"#366b51",0)
    for i in range(9):
        var x: float = -12+float(i%3)*12
        var z: float = -9+float(i/3)*8
        var slab = game._box(place,"Lastra_consumata",Vector3(x,.015,z),Vector3(1.4,.035,1.1),"#a3a387" if area == 0 else "#89968c")
        slab.rotation.y = float(i)*.22
    # Tetto aperto sui lati: l'occlusione lo rende trasparente vicino al giocatore.
    if area == 0:
        for x in [-4,4]:
            for z in [-2,-1,0,1,2]:
                for side in [-1,1]: game._box(place,"Nervatura",Vector3(x+side*1.53,.8,z),Vector3(.07,1.65,.12),"#9aa795")
            game._box(place,"Copertura_container",Vector3(x,1.65,0),Vector3(3.12,.12,5.1),"#a8b298")
        for x in [-13,-7]:
            for z in [-10,-5]: game._box(place,"Pilastro",Vector3(x,1.5,z),Vector3(.2,3,.2),"#866d49")
        var roof = game._box(place,"Copertura",Vector3(-10,3.2,-7.5),Vector3(7,.2,6),"#677e72")
        roof.rotation.z = .08
        for i in range(3): game._box(place,"Tavole_impilate",Vector3(9,.2+i*.23,1),Vector3(3,.18,1.4),"#bd9860")
    elif area == 1:
        for x in [-5,5]:
            game._box(place,"Condotta",Vector3(x,.5,-3.5),Vector3(.25,.3,7),"#b3b399")
            game._box(place,"Base_motore",Vector3(x,.1,2),Vector3(3,.2,3),"#727e73")
        game._box(place,"Pensilina",Vector3(0,3.5,-2),Vector3(7,.25,5),"#738d8b")
    else:
        for x in [-12,12]:
            game._box(place,"Supporto",Vector3(x,1.6,-10),Vector3(.25,3.2,.25),"#87866b")
            game._box(place,"Pannello",Vector3(x,2.6,-10),Vector3(2,.15,1.2),"#546f76",.2)
    preload("res://scripts/mission_landscape.gd").new().dress(game,place,area)
    game._cone(place,"Segnale_rientro",Vector3(0,.25,11),1.1,.06,"#b5cda3",1.1)

func _show_menu() -> void:
    menu.popup_centered()
    # Lascia libero il canale degli allarmi anche quando si consulta la bacheca.
    menu.position.y = maxi(menu.position.y,250)

func steer(at: Vector3, direction: Vector3) -> Vector3:
    # Aggiramento locale delle coperture; resta separato dall'IA delle orde alla base.
    if game.has_clear_path(at,at+direction*1.8): return direction
    var side := Vector3(-direction.z,0,direction.x)
    if game.has_clear_path(at,at+side*1.8): return side
    if game.has_clear_path(at,at-side*1.8): return -side
    return -direction

func objective_index() -> int:
    if primary: return -1
    if not ops.legacy_run and ops.phase > 0: return 2
    if not switches[0]: return 0
    if not switches[1]: return 1
    return 2

func objective_position() -> Vector3:
    if active_area < 0: return board.position
    if primary: return entrance(active_area)
    if not ops.legacy_run and ops.phase > 0: return ops.target()
    return point(active_area,objective_index())

func mission_instruction() -> String:
    var index := objective_index()
    var action := "4/4 Torna all'ingresso e premi F per consegnare"
    if index >= 0:
        var actions: Array = [
            ["1/4 Ispeziona il punto 1 [F]","2/4 Ispeziona il punto 2 [F]","3/4 Recupera la cassa principale [F]"],
            ["1/4 Scegli l'alimentazione al quadro 1 [F]","2/4 Ripristina il quadro 2 [F]","3/4 Recupera i componenti principali [F]"],
            ["1/4 Metti in sicurezza e rileva il punto 1 [F]","2/4 Rileva il punto 2 senza zombie vicini [F]","3/4 Recupera i risultati nella cassa [F]"]]
        action = actions[active_area][index]
    if not ops.legacy_run:
        if ops.phase > 0 and not primary: action = ops.instruction()
        elif not primary:
            action = [["1/4 Libera il primo fermo [F]","2/4 Libera il secondo fermo [F]","3/4 Avvia il verricello [F]"],["1/4 Imposta l'alimentazione [F]","2/4 Ripristina il quadro 2 [F]","3/4 Avvia e proteggi l'apparato [F]"],["1/4 Rileva il punto 1 [F]","2/4 Rileva il punto 2 [F]","3/4 Attiva la rete centrale [F]"]][active_area][index]
    var delta: Vector3 = objective_position()-game.hero.position
    var direction := "NORD" if delta.z < 0 else "SUD"
    if absf(delta.x) > absf(delta.z)*2: direction = "EST" if delta.x > 0 else "OVEST"
    elif absf(delta.x) > 2: direction += "-EST" if delta.x > 0 else "-OVEST"
    var cargo := "G: scopo e istruzioni | Risultato sempre trasportabile" if not ops.legacy_run else "G: guida | Conserva 1 posto per la cassa"
    if primary: cargo = "G: guida | Rientra o cerca carico facoltativo"
    elif bag_slots >= capacity(): cargo = "Carico pieno: rientra con il recupero parziale"
    return "%s\nCerchio sotto il bersaglio: %s · %dm | Carico %d/%d\n%s" % [action,direction,ceili(Vector2(delta.x,delta.z).length()),bag_slots,capacity(),cargo]

func show_collected_note(index: int) -> void:
    if not notes.has(index) or note_open: return
    var entries: Array = load("res://resources/field_entries.gd").new().entries
    game._end_camera_drag()
    note_previous_pause = game.paused
    game.paused = true
    note_open = true
    game.hero.clear_mouse_destination()
    note_dialog.dialog_text = entries[index]
    note_dialog.popup_centered(Vector2i(650,320))

func close_note() -> void:
    if not note_open: return
    note_dialog.hide()
    note_open = false
    game.paused = note_previous_pause

func show_mission_help() -> void:
    if active_area < 0 or game.paused: return
    game.hero.clear_mouse_destination()
    var purpose: String = ops.result_text(active_area) if not ops.legacy_run else "Consegna il recupero per conservare i materiali e completare la partita gia iniziata."
    _clear_menu("SCOPO DELLA MISSIONE\n"+purpose+"\n\nORA: "+mission_instruction()+"\n\nIl CERCHIO DORATO evidenzia un oggetto, non un percorso. Avvicinati e premi F quando richiesto.\nCompleta l'operazione, conferma il risultato, poi rientra.\nCasse facoltative e note sono secondarie. Puoi rinunciare e tornare prima.")
    _option("Riprendi la missione",func(): menu.hide())
    if not notes.is_empty(): _option("Rileggi ultimo appunto",func():
        menu.hide()
        show_collected_note(int(notes.back())))
    _show_menu()

func show_brief(area: int) -> void:
    if game.paused or not unlocked(area): return
    var repeat_notice := "\n\nRisultato gia acquisito: la rivisita conserva i potenziamenti e permette recuperi facoltativi, senza duplicare il premio iniziale." if ops.results[area] else ""
    _clear_menu(AREA_NAMES[area].to_upper()+"\n\nSCOPO E RISULTATO\n"+ops.result_text(area)+"\n\n"+[
        "Libera i due fermi, avvia il verricello e accompagna l'apparato al punto di rientro. Gli zombie possono danneggiarlo: resta vicino e proteggilo.",
        "Imposta l'alimentazione, ripristina il quadro e avvia la carica. Proteggi l'apparato e intervieni al quadro se l'alimentazione si interrompe.",
        "Rileva i due punti, avvia il collegamento e installa entrambi i sensori in sicurezza. Conferma il risultato all'apparato."
    ][area]+"\n\nPuoi ritirarti in ogni momento. La missione si completa quando torni con il risultato; i materiali facoltativi e le note sono secondari."+repeat_notice)
    _option("Parti per questa missione",func(): enter_area(area))
    _option("Torna alla bacheca",open_menu)
    _show_menu()

func apply_mission_result(area: int) -> void:
    if not ops.ready_to_collect(): return
    ops.results[area] = true
    if area in [0,1]:
        var key := "workshop" if area == 0 else "generator"
        var previous_hp := STATION_HP
        var existed: bool = stations.has(key)
        if existed:
            previous_hp = float(stations[key].hp)
            stations[key].node.queue_free()
            stations.erase(key)
        _create_station(key,previous_hp)
        if area == 1 and not existed: cells = maxi(0,cells-1)
    game.show_message(["Missione riuscita: officina attrezzata, kit con meno legno.","Missione riuscita: alimentazione stabilizzata, manutenzione piu efficiente.","Missione riuscita: rete di allerta collegata al rifugio."][area],6)

func kit_cost() -> int:
    return 2 if ops.results[0] else 4
