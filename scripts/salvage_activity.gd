extends Node3D
## Recupero facoltativo: carico persistente e consegna alla base.
const SITES: Array[Vector3] = [Vector3(-13,0,10),Vector3(-17,0,0),Vector3(-13,0,-13)]
const SEARCH_SECONDS := 4.0
const RESTOCK_SECONDS := 240.0
var game
var carried: int = 0
var technical_cargo := 0
var searching_technical := false
var deliveries: int = 0
var ready_at: Array[float] = [0.0,0.0,0.0]
var labels: Array[Label3D] = []
var crates: Array[Node3D] = []
var searching: int = -1
var progress: float = 0.0
var start_position := Vector3.ZERO

func configure(world: Node3D) -> void:
    game = world
    name = "Recupero_materiali"
    for index in range(SITES.size()):
        var site := Node3D.new()
        site.position = SITES[index]
        add_child(site)
        game._cone(site,"Radura",Vector3(0,.01,0),2.5,.025,"#867950",2.25)
        # Tre punti riconoscibili, senza ostacoli fisici sul percorso.
        if index == 0:
            for pole in [-1.0,1.0]:
                game._box(site,"Palo_tettoia",Vector3(pole,1,0),Vector3(.12,2,.12),"#71553d")
            game._box(site,"Copertura",Vector3(0,2.1,0),Vector3(2.7,.12,1.6),"#6d7963",.08)
        elif index == 1:
            for n in range(4):
                var log_mesh = game._cone(site,"Tronchi",Vector3(float(n%2)*.45-.2,.24+float(n/2)*.4,-.6),.22,2.2,"#816043",.2)
                log_mesh.rotation.x = PI*.5
        else:
            for n in range(5):
                game._rock(site,"Pietre",Vector3(float(n-2)*.6,.12,-.6),Vector3(.4,.25,.45),"#7b8275")
        var crate := Node3D.new()
        site.add_child(crate)
        game._box(crate,"Contenitore",Vector3(0,.35,.55),Vector3(.9,.7,.7),"#96724c")
        for x in [-.34,.34]:
            game._box(crate,"Fascia",Vector3(x,.36,.55),Vector3(.07,.73,.74),"#5b685e")
        crates.append(crate)
        var label := Label3D.new()
        label.position = Vector3(0,2.7,0)
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.font_size = 32
        label.pixel_size = .012
        label.outline_size = 5
        site.add_child(label)
        labels.append(label)
        game._register_occluders(site)
    # Segnaletica visiva vicina all'accesso della base.
    game._box(self,"Paletto",Vector3(-2, .7,7.5),Vector3(.12,1.4,.12),"#795a3e")
    game._box(self,"Indicazione_ovest",Vector3(-2,1.25,7.5),Vector3(1.2,.28,.12),"#b29465")
    var sign_label := Label3D.new()
    sign_label.text = "← RECUPERO | F"
    sign_label.position = Vector3(-2,1.6,7.5)
    sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign_label.font_size = 24
    sign_label.pixel_size = .007
    add_child(sign_label)

func interact() -> void:
    if game.paused or searching >= 0:
        return
    for index in range(SITES.size()):
        if game.hero.global_position.distance_to(SITES[index]) > 2.6:
            continue
        if carried >= 3:
            game.show_message("Carico pieno: riportalo al rifugio.",2.5)
        elif game.elapsed < ready_at[index]:
            game.show_message("Materiali gia' recuperati: esplora un altro punto.",2.5)
        elif game.frontier.growth.technical_salvage and (not game.frontier.growth.active("workshop") or not game.frontier.tool):
            game.show_message("Smontaggio non disponibile: ripara officina II o prepara il legname alla bacheca.",4)
        else:
            searching_technical = game.frontier.growth.technical_salvage
            searching = index
            progress = 0.0
            start_position = game.hero.global_position
            game.hero.clear_mouse_destination()
            game.make_noise(SITES[index],4.0)
        return
    game.show_message("Cerca i punti di recupero a OVEST e premi F vicino alle casse.",3.0)

func _process(delta: float) -> void:
    if game == null or game.paused:
        return
    for index in range(labels.size()):
        var distance: float = game.hero.global_position.distance_to(SITES[index])
        labels[index].visible = distance < 9
        crates[index].visible = game.elapsed >= ready_at[index]
        labels[index].text = ("SMONTAGGIO | F" if game.frontier.growth.technical_salvage else "RECUPERO | F") if game.elapsed >= ready_at[index] else "ESAURITO | %ds" % ceili(ready_at[index]-game.elapsed)
    if searching >= 0:
        if game.hero.global_position.distance_to(start_position) > .65 or game.hero.since_last_hit < .25:
            searching = -1
            progress = 0.0
            game.show_message("Recupero interrotto. Premi F per riprovare.",2.0)
        else:
            progress += delta
            labels[searching].text = "RECUPERO %d%%" % mini(100,int(progress/SEARCH_SECONDS*100))
            if progress >= SEARCH_SECONDS:
                _complete_search()
    if carried > 0 and absf(game.hero.position.x) < 3.5 and game.hero.position.z > -1.5 and game.hero.position.z < 2.8:
        deposit()

func _complete_search() -> void:
    if searching < 0:
        return
    var site: int = searching
    searching = -1
    progress = 0.0
    ready_at[site] = game.elapsed + RESTOCK_SECONDS
    carried += 1
    if searching_technical: technical_cargo += 1
    searching_technical = false
    # Il rischio cresce solo se si sceglie di proseguire con il carico.
    for index in range(carried):
        if game.enemies.size() >= 28:
            break
        var spawn := SITES[site] + Vector3(4+float(index),.13,-4)
        spawn.x = clampf(spawn.x,-19,19)
        spawn.z = clampf(spawn.z,-19,19)
        game._spawn_enemy(spawn,"normal",false)
    game.make_noise(SITES[site],8.0)
    game.show_message("Carico %d/3 | tecnici %d: consegna per conservare il recupero." % [carried,technical_cargo],3.5)
    game._save_progress()

func deposit() -> void:
    if game.paused or absf(game.hero.position.x) >= 3.5 or game.hero.position.z <= -1.5 or game.hero.position.z >= 2.8:
        return
    if carried <= 0:
        return
    var wood_reward: int = (carried-technical_cargo)*12+technical_cargo*6
    var coin_reward: int = (carried-technical_cargo)*8 + (10 if carried-technical_cargo == 3 else 0)
    var parts_reward: int = technical_cargo
    game.frontier.parts += parts_reward
    game.wood += wood_reward
    game.coins += coin_reward
    carried = 0
    technical_cargo = 0
    deliveries += 1
    game.show_message("CARICO CONSEGNATO: +%d LEGNO, +%d MONETE, +%d COMPONENTI" % [wood_reward,coin_reward,parts_reward],3.0)
    game._save_progress()

func save_data() -> Dictionary:
    return {"carried":carried,"technical_cargo":technical_cargo,"deliveries":deliveries,"ready_at":ready_at}

func load_data(data: Variant) -> void:
    searching = -1
    progress = 0.0
    carried = 0
    technical_cargo = 0
    searching_technical = false
    deliveries = 0
    ready_at = [0.0,0.0,0.0]
    if not data is Dictionary:
        return
    carried = clampi(int(data.get("carried",0)),0,3)
    technical_cargo = clampi(int(data.get("technical_cargo",0)),0,carried)
    deliveries = maxi(0,int(data.get("deliveries",0)))
    var times = data.get("ready_at",[])
    if times is Array:
        for index in range(mini(times.size(),3)):
            ready_at[index] = maxf(0,float(times[index]))

func drop_carried() -> void:
    technical_cargo = 0
    searching_technical = false
    searching = -1
    progress = 0.0
    carried = 0
