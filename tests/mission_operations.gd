extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void: call_deferred("run")
func quiet(game) -> void:
    for enemy in game.enemies:
        if is_instance_valid(enemy):
            enemy.defeated = true
            enemy.queue_free()
    game.enemies.clear()
func prepare(game, area: int) -> void:
    var f = game.frontier
    for index in range(2):
        game.hero.position = f.point(area,index)
        f.interact()
        if area == 1 and index == 0: f.set_power_mode(false)
    game.hero.position = f.point(area,2)
    f.interact()
func collect_and_return(game) -> void:
    var f = game.frontier
    game.hero.position = f.ops.pickup_position()
    f.interact()
    check(f.primary and f.note_open,"Appunto secondario aperto dopo il risultato operativo")
    f.close_note()
    game.hero.position = f.entrance(f.active_area)
    f.interact()
func run() -> void:
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",ProjectSettings.globalize_path("user://operation-tests"))
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.set_process(false)
    game.hero.set_physics_process(false)
    game.frontier.set_process(false)
    game.frontier.ops.set_process(false)
    game.expedition.set_physics_process(false)
    game.salvage.set_process(false)
    game.skip_save_on_exit = true
    quiet(game)
    game.stockade_built = true
    game.base_level = 2
    game.wood = 200
    game._build_stockade()
    var f = game.frontier
    var ops = f.ops
    game.hero.position = f.board.position
    f.show_brief(0)
    check(f.menu_body.get_child(0).text.contains("SCOPO E RISULTATO"),"Scopo e risultato spiegati prima della partenza")
    f.enter_area(0)
    quiet(game)
    check(not ops.legacy_run and ops.phase == 0,"Nuova missione usa un operazione reale")
    game.hero.position = f.point(0,2)
    f.take_loot(2,false)
    check(not f.primary and not f.note_open,"Non basta raccogliere una cassa per completare il nuovo incarico")
    prepare(game,0)
    quiet(game)
    check(ops.phase == 1,"Preparazione avvia il recupero fisico")
    var initial_z: float = ops.payload_z
    game.hero.position = f.entrance(0)
    ops.advance(.25)
    check(ops.payload_z == initial_z,"Il recupero si ferma se il protagonista lo abbandona")
    game.hero.position = ops.machine_position()+Vector3(0,0,6)
    game._spawn_enemy(ops.machine_position()+Vector3(1.4,0,0),"normal",false)
    var enemy = game.enemies.back()
    enemy.set_physics_process(false)
    await physics_frame
    await physics_frame
    enemy._physics_process(.1)
    check(ops.hp < ops.MAX_HP,"Gli zombie possono danneggiare l obiettivo operativo")
    quiet(game)
    ops.damage(1000)
    check(ops.phase == 3 and ops.visuals[0].rubble.visible,"Fallimento con crollo riconoscibile e nessun premio")
    game.hero.position = ops.machine_position()
    f.interact()
    quiet(game)
    check(ops.phase == 1 and ops.hp == ops.MAX_HP and not f.primary,"Tentativo ripristinabile senza perdere progressi precedenti")
    for i in range(50):
        game.hero.position = ops.machine_position()
        ops.advance(.25)
    check(ops.phase == 2 and is_equal_approx(ops.payload_z,8),"L apparato viene effettivamente accompagnato al rientro")
    game.hero.position = f.point(0,3)
    f.take_loot(3,true)
    game.hero.position = f.point(0,4)
    f.take_loot(4,false)
    check(f.bag_slots == f.capacity(),"Carico facoltativo pieno prima del risultato")
    quiet(game)
    collect_and_return(game)
    check(f.completed[0] and f.working("workshop") and ops.results[0],"La missione installa davvero l officina al rifugio")
    check(f.kit_cost() == 2,"Risultato della prima missione migliora concretamente l officina")
    check(game.wood == 235 and f.parts == 6,"Consegna del risultato possibile anche a carico pieno, premio unico")
    var timber: int = game.wood
    f.leave_area(true)
    check(game.wood == timber,"Rientro non duplica il premio")
    game.hero.position = f.board.position
    f.craft_tool()
    f.menu.hide()
    f.enter_area(1)
    quiet(game)
    prepare(game,1)
    quiet(game)
    game.hero.position = ops.machine_position()
    game.paused = true
    ops.advance(.25)
    check(ops.progress == 0,"Pausa sospende l operazione")
    game.paused = false
    for i in range(40): ops.advance(.25)
    check(ops.fault and is_equal_approx(ops.progress,.4),"La carica richiede un intervento concreto al quadro")
    var stopped: float = ops.progress
    ops.advance(100)
    check(ops.progress == stopped and not f.primary,"Attendere non sostituisce la riparazione richiesta")
    ops.hp = 61
    game._save_progress()
    ops.progress = 0
    ops.fault = false
    game._load_progress()
    await process_frame
    quiet(game)
    check(ops.phase == 1 and ops.fault and ops.hp == 61 and is_equal_approx(ops.progress,.4),"Ricaricamento conserva carica, guasto e salute senza completare la missione")
    game.hero.position = f.point(1,1)
    f.interact()
    check(ops.fixed and not ops.fault,"Interazione al quadro risolve il guasto")
    game.hero.position = ops.machine_position()
    for i in range(60): ops.advance(.25)
    check(ops.phase == 2,"Operazione completata dopo intervento e protezione")
    collect_and_return(game)
    check(f.working("generator") and ops.results[1] and f.cells == 0,"Consegna installa il generatore usando il risultato recuperato")
    game.wall_segments[0].hp = 120
    check(game.repair_cost("wall:0") == 5,"Alimentazione stabilizzata riduce il costo della manutenzione")
    game.wall_segments[0].hp = 240
    f.stations.generator.hp = 37
    ops.phase = 2
    f.apply_mission_result(1)
    check(f.stations.generator.hp == 37,"Ripetere una missione non ripara gratuitamente una costruzione esistente")
    ops.phase = 0
    game.hero.position = f.board.position
    f.enter_area(2)
    quiet(game)
    # Le letture iniziali si svolgono dopo aver messo in sicurezza ogni punto.
    for index in range(2):
        game.hero.position = f.point(2,index)
        f.interact()
        quiet(game)
    game.hero.position = f.point(2,2)
    f.interact()
    quiet(game)
    check(ops.phase == 1,"Ultima attivita avvia un collegamento invece di un altra cassa")
    game.hero.position = f.point(2,3)
    game._spawn_enemy(game.hero.position+Vector3(1,0,0),"normal",false)
    game.enemies.back().set_physics_process(false)
    f.interact()
    check(ops.beacons.is_empty(),"Sensore collegabile soltanto in sicurezza")
    quiet(game)
    f.interact()
    check(ops.beacons.size() == 1 and ops.phase == 1,"Primo sensore ha uno stato operativo distinto")
    game.hero.position = f.point(2,2)
    f.take_loot(2,false)
    check(not f.primary,"Conferma impossibile prima del collegamento completo")
    game.hero.position = f.point(2,4)
    f.interact()
    check(ops.phase == 2 and ops.beacons.size() == 2,"Entrambi i sensori attivano il risultato concreto")
    collect_and_return(game)
    check(ops.results[2] and f.completed == [true,true,true],"Rete e progressi registrati dopo la consegna")
    game.elapsed = 100
    game.next_raid = 140
    game.alerts.warned_raid = -1
    game.alerts.tick()
    check(game.alerts.raid_label.visible,"Rete alimentata offre un preavviso realmente piu lungo")
    f.stations.generator.hp = 0
    game.elapsed = 200
    game.next_raid = 240
    game.alerts.warned_raid = -1
    game.alerts.tick()
    check(not game.alerts.raid_label.visible,"Senza generatore resta il preavviso normale")
    f.restore_station("generator")
    game.alerts.tick()
    check(game.alerts.raid_label.visible,"Riparare il generatore ripristina la rete di allerta")
    game._save_progress()
    ops.results = [false,false,false]
    game._load_progress()
    await process_frame
    check(ops.results == [true,true,true],"Risultati permanenti conservati nei salvataggi v8")
    var legacy: Dictionary = f.save_data()
    legacy.erase("mission_ops")
    legacy.active_area = 0
    legacy.primary = false
    legacy.used = [0,1]
    legacy.switches = [true,true]
    legacy.bag_slots = 0
    legacy.bag_parts = 0
    f.load_data(legacy)
    quiet(game)
    check(ops.legacy_run and f.completed == [true,true,true],"Missione gia iniziata nel vecchio formato resta completabile senza reset")
    game.hero.position = f.point(0,2)
    f.take_loot(2,false)
    check(f.primary and f.note_open,"Vecchio recupero e lettura immediata compatibili")
    f.close_note()
    game.queue_free()
    await process_frame
    print("Operazioni distinte e risultati persistenti: %d errori" % failures)
    quit(1 if failures else 0)
