extends RefCounted
## Crescita del rifugio: investimenti manuali, mai produzione passiva.
const UPGRADES := {
    "workshop":{"title":"Officina attrezzata II","wood":18,"parts":2,"cells":0,"after":0,"benefit":"Sblocca lo smontaggio dei recuperi nel bosco: ogni carico tecnico consegna 6 legno e 1 componente, senza monete. Kit: cura 85 HP e scorta fino a 5."},
    "storage":{"title":"Magazzino organizzato II","wood":22,"parts":3,"cells":0,"after":1,"benefit":"Porta il carico facoltativo delle spedizioni da 5 a 7 posti. Il recupero nel bosco e il carretto mantengono la capacita gia collaudata."},
    "generator":{"title":"Generatore efficiente II","wood":24,"parts":3,"cells":0,"after":2,"benefit":"Manutenzione con il 35% di legno in meno. Con la rete gia collegata, preavviso orda di 60 secondi. Illuminazione locale nel cortile."}
}
var levels: Dictionary = {}
var technical_salvage := false
var f
var game
func configure(frontier) -> void:
    f = frontier
    game = f.game
func level(key: String) -> int:
    return int(levels.get(key,1))
func active(key: String) -> bool:
    return level(key) == 2 and f.working(key)
func requirement(key: String) -> String:
    if not UPGRADES.has(key): return "Potenziamento non disponibile"
    if level(key) >= 2: return "Potenziamento gia installato"
    if not f.stations.has(key): return "Costruisci prima la postazione"
    if not f.working(key): return "Ripara prima la postazione"
    if not f.completed[int(UPGRADES[key].after)]: return "Concludi e consegna la spedizione %d" % (int(UPGRADES[key].after)+1)
    return ""
func affordable(key: String) -> bool:
    if not UPGRADES.has(key): return false
    var cost: Dictionary = UPGRADES[key]
    return game.wood >= cost.wood and f.parts >= cost.parts and f.cells >= cost.cells
func context_ok() -> bool:
    return not game.paused and f.active_area < 0 and game.hero.position.distance_to(f.board.position) <= 6
func open_menu() -> void:
    if not context_ok(): return
    game.hero.clear_mouse_destination()
    f._clear_menu("CRESCITA DEL RIFUGIO\nLegno %d | Componenti %d | Celle %d\n%s\nI benefici richiedono postazioni funzionanti. I danni restano da riparare." % [game.wood,f.parts,f.cells,status()])
    for key in UPGRADES:
        var id: String = key
        var info: Dictionary = UPGRADES[key]
        var reason := requirement(key)
        var quote := "%d legno + %d componenti%s" % [info.wood,info.parts," + 1 cella" if info.cells > 0 else ""]
        f._option(info.title+" | "+("INSTALLATO" if level(key) == 2 else quote),func(): show_quote(id),level(key) == 2)
        var line := Label.new()
        line.text = info.benefit+("\n"+reason if not reason.is_empty() and level(key) < 2 else "")
        line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        line.custom_minimum_size.x = 560
        f.menu_body.add_child(line)
    var mode := "COMPONENTI: 6 legno + 1 componente, niente monete" if technical_salvage else "LEGNAME: 12 legno + 8 monete per carico"
    f._option("Preparazione bosco: "+mode,show_salvage_options)
    f._option("Torna alla bacheca",f.open_menu)
    f._show_menu()
func show_quote(key: String) -> void:
    if not context_ok() or not UPGRADES.has(key): return
    var info: Dictionary = UPGRADES[key]
    var reason := requirement(key)
    f._clear_menu(info.title+"\n\n"+str(info.benefit)+"\n\nCosto: %d legno, %d componenti, %d celle.\n%s\nSalute e danni della struttura vengono conservati." % [info.wood,info.parts,info.cells,reason if not reason.is_empty() else ("Materiali disponibili." if affordable(key) else "Materiali insufficienti: nessuna risorsa verra spesa.")])
    f._option("Installa il potenziamento",func(): upgrade(key),not reason.is_empty() or not affordable(key))
    f._option("Indietro",open_menu)
    f._show_menu()
func upgrade(key: String) -> bool:
    if not context_ok() or not requirement(key).is_empty(): return false
    if not affordable(key):
        game.show_message("Materiali insufficienti: potenziamento non eseguito.",3)
        return false
    var cost: Dictionary = UPGRADES[key]
    var hp: float = f.stations[key].hp
    game.wood -= int(cost.wood)
    f.parts -= int(cost.parts)
    f.cells -= int(cost.cells)
    levels[key] = 2
    f.stations[key].node.queue_free()
    f.stations.erase(key)
    f._create_station(key,hp)
    game.show_message("Potenziamento installato: %s. G: dettagli." % cost.title,5)
    game._save_progress()
    open_menu()
    return true
func show_salvage_options() -> void:
    if not context_ok(): return
    f._clear_menu("PREPARA IL RECUPERO NEL BOSCO\nScegli prima di uscire. Ricompense soltanto alla consegna; perdere il carico perde anche i componenti.\nLegname: 12 legno + 8 monete per carico, bonus monete con 3 carichi.\nSmontaggio: 6 legno + 1 componente per carico, senza monete. Richiede officina II funzionante e attrezzi.\nNon cambia le spedizioni o il carretto.")
    var occupied: bool = game.salvage.carried > 0 or game.salvage.searching >= 0
    if occupied:
        var label := Label.new()
        label.text = "Consegna prima il carico: la preparazione resta bloccata durante il recupero."
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.custom_minimum_size.x = 560
        f.menu_body.add_child(label)
    f._option("Prepara recupero di legname",func(): set_salvage_mode(false),occupied)
    f._option("Prepara smontaggio per componenti",func(): set_salvage_mode(true),occupied or not active("workshop") or not f.tool)
    f._option("Indietro",open_menu)
    f._show_menu()
func set_salvage_mode(technical: bool) -> bool:
    if not context_ok() or game.salvage.carried > 0 or game.salvage.searching >= 0: return false
    if technical and (not active("workshop") or not f.tool): return false
    technical_salvage = technical
    game._save_progress()
    open_menu()
    return true
func status() -> String:
    var count := 0
    for key in UPGRADES:
        if level(key) == 2: count += 1
    return "Potenziamenti rifugio: %d/3 | G: crescita e preparazione" % count
func repair_factor() -> float:
    if active("generator"): return .65
    return .8 if f.ops.results[1] and f.working("generator") else 1.0
func warning_seconds() -> int:
    if not f.ops.results[2] or not f.working("generator"): return 20
    return 60 if active("generator") else 45
func kit_capacity() -> int:
    return 5 if active("workshop") else 3
func kit_healing() -> float:
    return 85.0 if active("workshop") else 65.0
func dress_station(key: String, node: Node3D) -> Array:
    if level(key) < 2: return []
    var art = preload("res://scripts/mission_landscape.gd").new()
    var meshes: Array = []
    if key == "workshop":
        for x in [-.8,.8]: meshes.append(art.box(node,Vector3(x,1.1,-.46),Vector3(.12,2.2,.12),"#817355","wood"))
        meshes.append(art.box(node,Vector3(0,2.2,-.05),Vector3(1.9,.12,1.4),"#637e73"))
        meshes.append(art.box(node,Vector3(-.4,.45,-.1),Vector3(.65,.65,.7),"#9b8864","wood"))
        for i in range(3): meshes.append(art.box(node,Vector3(-.4,.28+i*.18,.27),Vector3(.55,.13,.06),"#b09c75","wood"))
    elif key == "storage":
        for y in [.25,1.2]:
            meshes.append(art.box(node,Vector3(0,y,0),Vector3(1.65,.12,1.05),"#a08d68","wood"))
            for x in [-.45,.45]: meshes.append(art.box(node,Vector3(x,y+.25,0),Vector3(.65,.4,.75),"#8f805e","wood"))
        for x in [-.82,.82]: meshes.append(art.box(node,Vector3(x,1.0,0),Vector3(.08,1.9,1.1),"#687d70"))
    else:
        meshes.append(art.box(node,Vector3(-.48,.9,0),Vector3(.55,1.35,.85),"#879485"))
        for y in [.55,.7,.85,1.0]: meshes.append(art.box(node,Vector3(-.48,y,.45),Vector3(.45,.045,.035),"#415c51"))
        meshes.append(art.box(node,Vector3(0,1.65,-.35),Vector3(1.65,.15,.18),"#7a8979"))
        for x in [-.68,.68]:
            meshes.append(art.box(node,Vector3(x,1.5,-.35),Vector3(.14,1.2,.14),"#7b806c"))
            meshes.append(art.box(node,Vector3(x,2.12,-.3),Vector3(.3,.12,.3),"#ddc78d"))
        var light := OmniLight3D.new()
        light.name = "Luce_potenziamento"
        light.position = Vector3(0,2.0,0)
        light.light_color = Color("#f3dab0")
        light.light_energy = .6
        light.omni_range = 4.5
        light.shadow_enabled = false
        node.add_child(light)
    return meshes
func sync_lights() -> void:
    if not f.stations.has("generator"): return
    var light = f.stations.generator.node.get_node_or_null("Luce_potenziamento")
    if light != null: light.visible = f.working("generator")
func save_data() -> Dictionary:
    return {"levels":levels.duplicate(),"technical_salvage":technical_salvage}
func load_data(data) -> void:
    levels.clear()
    technical_salvage = false
    if not data is Dictionary: return
    var stored = data.get("levels",{})
    if stored is Dictionary:
        for key in UPGRADES: levels[key] = clampi(int(stored.get(key,1)),1,2)
    technical_salvage = bool(data.get("technical_salvage",false))
