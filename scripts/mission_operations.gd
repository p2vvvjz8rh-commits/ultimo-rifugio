extends Node3D
## Operazioni di campo con risultati persistenti; i vecchi incarichi restano completabili.
const MAX_HP := 120.0
var f
var game
var legacy_run := false
var phase := 0 # preparazione, operazione, risultato pronto, guasto totale
var hp := MAX_HP
var progress := 0.0
var payload_z := -10.0
var fault := false
var fixed := false
var beacons: Array = []
var results: Array = [false,false,false]
var machines: Array = []
var visuals: Array = []
var labels: Array = []
var restraints: Array = []
var sensor_models: Array = []
func configure(frontier) -> void:
    f = frontier
    game = f.game
    for area in range(3):
        var model := Node3D.new()
        f.models[area].add_child(model)
        model.position = Vector3(0,0,-10)
        machines.append(model)
        var meshes: Array = []
        meshes.append(game._box(model,"Telaio",Vector3(0,.35,0),Vector3(1.7,.25,1.6),"#716044"))
        meshes.append(game._box(model,"Apparato",Vector3(0,.9,0),Vector3(1.3,.9,1.1),["#8c7855","#628176","#687c83"][area]))
        if area == 0:
            meshes.append(game._box(model,"Morsa",Vector3(.4,1.5,0),Vector3(.4,.4,.5),"#8a9996"))
            for i in range(2):
                var brace = game._box(model,"Fermo_%d" % i,Vector3(-.55+i*1.1,1,0),Vector3(.12,1.1,1.2),"#baa071")
                restraints.append(brace)
                meshes.append(brace)
        else:
            meshes.append(game._cone(model,"Bobina",Vector3(0,1.55,0),.32,.45,"#c5b171",.32))
        var visual = game._make_structure_visual(model,"station",MAX_HP,Vector3(0,2.7,0))
        visual.bind_meshes(meshes)
        visuals.append(visual)
        labels.append(f._label3(model,Vector3(0,2.1,0),""))
        game._register_occluders(model)
    for index in [3,4]:
        var node := Node3D.new()
        node.position = f.point(2,index)-f.center(2)
        f.models[2].add_child(node)
        game._box(node,"Palo_sensore",Vector3(0,.8,0),Vector3(.12,1.6,.12),"#827557")
        game._box(node,"Sensore",Vector3(0,1.6,0),Vector3(.5,.45,.4),"#7c948a")
        var status = game._cone(node,"Stato",Vector3(0,1.95,0),.18,.25,"#e4be64",.18)
        var label = f._label3(node,Vector3(0,2.5,0),"F: COLLEGA SENSORE")
        sensor_models.append({"node":node,"status":status,"label":label})
    sync_visuals()
func reset() -> void:
    legacy_run = false
    phase = 0
    hp = MAX_HP
    progress = 0
    payload_z = -10
    fault = false
    fixed = false
    beacons.clear()
    sync_visuals()
func ready_to_collect() -> bool:
    return legacy_run or phase == 2
func machine_position() -> Vector3:
    if f.active_area < 0: return Vector3.ZERO
    return machines[f.active_area].global_position
func pickup_position() -> Vector3:
    return f.point(f.active_area,2) if legacy_run else machine_position()
func start() -> void:
    if game.paused or legacy_run or f.active_area < 0 or not f.switches[0] or not f.switches[1]: return
    if game.hero.position.distance_to(machine_position()) > 2.6: return
    if phase == 1:
        game.show_message(instruction(),3)
        return
    if phase == 2: return
    var resume_haul: bool = phase == 3 and f.active_area == 0
    hp = MAX_HP
    phase = 1
    progress = (payload_z+10.0)/18.0 if resume_haul else 0.0
    if not resume_haul: payload_z = -10
    fault = false
    fixed = false
    beacons.clear()
    f._spawn_group(f.point(f.active_area,2)+Vector3(4,0,3),2)
    sync_visuals()
    game.show_message(instruction(),5)
    game._save_progress()
func _process(delta: float) -> void:
    advance(delta)
func advance(delta: float) -> void:
    if game == null or game.paused or legacy_run or f.active_area < 0 or phase != 1: return
    var step := clampf(delta,0,.25)
    if f.active_area == 0:
        if game.hero.position.distance_to(machine_position()) > 4.5: return
        payload_z = move_toward(payload_z,8.0,step*1.6)
        progress = (payload_z+10.0)/18.0
        if payload_z >= 8: finish()
    elif f.active_area == 1:
        if game.hero.position.distance_to(machine_position()) > 8 or fault: return
        progress += step/20.0
        if not fixed and progress >= .4:
            progress = .4
            fault = true
            game.show_message("Alimentazione interrotta! Ripristina il quadro 2 [F] e proteggi l'apparato.",5)
            game._save_progress()
        if progress >= 1: finish()
    sync_visuals()
func repair_fault() -> void:
    if game.paused or phase != 1 or not fault or f.active_area != 1: return
    if game.hero.position.distance_to(f.point(1,1)) > 2.6: return
    fault = false
    fixed = true
    sync_visuals()
    game.show_message("Alimentazione ripristinata. Proteggi l'apparato fino al termine.",4)
    game._save_progress()
func install_beacon(index: int) -> void:
    if game.paused or f.active_area != 2 or phase != 1 or index not in [3,4] or beacons.has(index): return
    if game.hero.position.distance_to(f.point(2,index)) > 2.6: return
    if game.closest_enemy(game.hero.position,4) != null:
        game.show_message("Metti in sicurezza il sensore prima di collegarlo.",3)
        return
    beacons.append(index)
    progress = float(beacons.size())/2.0
    if beacons.size() == 2: finish()
    sync_visuals()
    game._save_progress()
func finish() -> void:
    phase = 2
    progress = 1
    sync_visuals()
    game.show_message("Operazione riuscita. Conferma il risultato all'apparato [F], poi rientra.",5)
    game._save_progress()
func target_available(at: Vector3) -> bool:
    return not legacy_run and phase == 1 and f.active_area >= 0 and at.x > 40 and at.distance_to(machine_position()) < 8 and game.has_clear_path(at,machine_position())
func damage(amount: float) -> void:
    if game.paused or phase != 1: return
    hp = maxf(0,hp-maxf(0,amount))
    if hp <= 0:
        phase = 3
        game.show_message("Apparato fuori uso. Avvicinati e premi F per riprovare, oppure rientra.",5)
    sync_visuals()
    game._save_progress()
func target() -> Vector3:
    if phase == 1 and f.active_area == 1 and fault: return f.point(1,1)
    if phase == 1 and f.active_area == 2:
        return f.point(2,3 if not beacons.has(3) else 4)
    return machine_position()
func instruction() -> String:
    if phase == 3: return "APPARATO GUASTO: avvicinati e ripristinalo [F]"
    if phase == 2: return "OPERAZIONE RIUSCITA: conferma il risultato [F]"
    if f.active_area == 0: return "Accompagna l'officina al rientro: resta entro 4,5m e proteggila"
    if f.active_area == 1:
        return "Ripristina il quadro 2 [F]" if fault else "Proteggi l'apparato: carica %d%% | resta entro 8m" % roundi(progress*100)
    return "Collega i sensori [F] in sicurezza: %d/2" % beacons.size()
func result_text(area: int) -> String:
    return ["Attrezza l'officina: al rientro viene installata o potenziata nel cortile. I kit richiedono 2 legno invece di 4, oltre a 1 componente.","Stabilizza l'alimentazione: al rientro il generatore viene installato o potenziato. Quando funziona, le riparazioni richiedono il 20% di legno in meno.","Rete collegata: con il generatore funzionante, il preavviso delle orde aumenta da 20 a 45 secondi."][area]
func sync_visuals() -> void:
    if machines.is_empty(): return
    for area in range(3):
        var active: bool = f.active_area == area and not legacy_run
        machines[area].visible = active and not f.primary
        if active:
            visuals[area].set_health(hp)
            labels[area].text = instruction() if phase != 0 else ["3: AVVIA IL VERRICELLO [F]","3: AVVIA E PROTEGGI [F]","3: ATTIVA IL COLLEGAMENTO [F]"][area]
            f.point_models[area][2].visible = false
            for index in range(2):
                f.point_models[area][index].visible = true
                var failed: bool = area == 1 and index == 1 and fault
                for child in f.point_models[area][index].get_children():
                    if child is Label3D:
                        var title: String = ["SGANCIA IL FERMO","RIPRISTINA IL QUADRO","RILEVA IL PUNTO"][area]
                        if f.switches[index]: title = ["FERMO LIBERATO","QUADRO PRONTO","PUNTO RILEVATO"][area]
                        if failed: title = "GUASTO: RIPRISTINA [F]"
                        child.text = "%d: %s" % [index+1,title]
                    if child is MeshInstance3D and child.get_meta("visual_role","") == "Quadro":
                        child.material_override = game._mat("#b3744a" if failed else ("#67947b" if f.switches[index] else "#617d80"))
    machines[0].position.z = payload_z
    for index in range(restraints.size()): restraints[index].visible = not f.switches[index] if f.active_area == 0 else true
    for i in range(sensor_models.size()):
        var sensor: Dictionary = sensor_models[i]
        sensor.node.visible = f.active_area == 2 and not legacy_run
        if f.active_area == 2 and not legacy_run:
            f.point_models[2][i+3].visible = false
            sensor.label.text = "SENSORE COLLEGATO" if beacons.has(i+3) else "F: COLLEGA SENSORE"
            sensor.status.material_override = game._mat("#81d7a0" if beacons.has(i+3) else "#e4be64")
func save_data() -> Dictionary:
    return {"legacy":legacy_run,"phase":phase,"hp":hp,"progress":progress,"payload_z":payload_z,"fault":fault,"fixed":fixed,"beacons":beacons,"results":results}
func load_data(data, old_active: bool) -> void:
    reset()
    results = [false,false,false]
    if not data is Dictionary or data.is_empty():
        legacy_run = old_active
        sync_visuals()
        return
    legacy_run = bool(data.get("legacy",false))
    phase = clampi(int(data.get("phase",0)),0,3)
    hp = clampf(float(data.get("hp",MAX_HP)),0,MAX_HP)
    progress = clampf(float(data.get("progress",0)),0,1)
    payload_z = clampf(float(data.get("payload_z",-10)),-10,8)
    fault = bool(data.get("fault",false))
    fixed = bool(data.get("fixed",false))
    for index in data.get("beacons",[]):
        if int(index) in [3,4] and not beacons.has(int(index)): beacons.append(int(index))
    var saved_results = data.get("results",[])
    for i in range(3): results[i] = bool(saved_results[i]) if saved_results is Array and saved_results.size() > i else false
    sync_visuals()

func target_caption() -> String:
    if phase == 3: return "RIPRISTINA APPARATO [F]"
    if phase == 2: return "CONFERMA RISULTATO [F]"
    if f.active_area == 0: return "ACCOMPAGNA E PROTEGGI"
    if f.active_area == 1: return "RIPRISTINA QUADRO 2 [F]" if fault else "PROTEGGI L'APPARATO"
    return "COLLEGA SENSORE [F]"
