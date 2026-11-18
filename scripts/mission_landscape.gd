extends RefCounted
## Allestimento statico: nessuna modifica a collisioni, premi o percorsi obbligati.
func dress(game, place: Node3D, area: int) -> void:
    var random := RandomNumberGenerator.new()
    random.seed = 48152+area*71
    var details := Node3D.new()
    details.name = "Ambiente_spedizione"
    place.add_child(details)
    # Sentieri leggibili fra ingresso, attivita e recupero; non hanno collisioni.
    var route := [Vector3(0,0,11),Vector3(-10,0,5),Vector3(-10,0,-7),Vector3(0,0,-10),Vector3(10,0,-6),Vector3(10,0,6)]
    for segment in range(route.size()-1):
        var a: Vector3 = route[segment]
        var b: Vector3 = route[segment+1]
        var steps := ceili(a.distance_to(b)/1.2)
        for j in range(steps+1):
            var at := a.lerp(b,float(j)/maxi(1,steps))
            var patch = game._cone(details,"Terra_calpestata",at+Vector3(0,.018,0),1.05,.025,["#898465","#7b8379","#8e8a70"][area],1.05)
            patch.scale.z = .8
    for i in range(85):
        var at := Vector3(random.randf_range(-15.5,15.5),.035,random.randf_range(-13,13))
        if _task_clearance(at) < 2.7: continue
        var edge: bool = absf(at.x) > 11.5 or absf(at.z) > 10.5
        if edge or i%3 == 0:
            game._cone(details,"Ciuffo_erba",at+Vector3(0,.18,0),.2,.36,"#697e4c",.04)
            game._cone(details,"Erba_secondaria",at+Vector3(.17,.12,.08),.13,.24,"#879454",.02)
        if edge and i%4 == 0:
            game._rock(details,"Pietra",at+Vector3(0,.12,0),Vector3(.5,.3,.4),"#8d9482")
        elif i%5 == 0:
            var litter = game._box(details,"Detrito",at,Vector3(.3,.025,.15),"#a8a181")
            litter.rotation.y = random.randf_range(0,TAU)
    # Fasce di cespugli e massi spezzano il bordo rettangolare della radura.
    for side in [-1,1]:
        for j in range(7):
            var at := Vector3(side*(14.2+random.randf()*.5),.15,-10+j*3.2)
            game._rock(details,"Cespuglio",at,Vector3(.8,.55,.7),"#477251")
            if j%2 == 0: game._rock(details,"Masso",at+Vector3(-side*.7,.15,.8),Vector3(.8,.6,.7),"#859184")
    if area == 0:
        for at in [Vector3(-12,0,-1),Vector3(12,0,-1),Vector3(5,0,-12)]:
            _pallet(game,details,at)
            _crate(game,details,at+Vector3(0,.2,0))
            _crate(game,details,at+Vector3(.6,1,0),.65)
        for i in range(5):
            var log = game._cone(details,"Legname",Vector3(6+i*.35,.4,7.5),.16,2.5,"#9a7950",.16)
            log.rotation.x = PI*.5
        _table(game,details,Vector3(-12,0,9),"#a2865e")
        game._box(details,"Carrello_pianale",Vector3(8,.45,9),Vector3(2,.18,1.3),"#657e76")
        for x in [7.3,8.7]:
            for z in [8.6,9.4]:
                var wheel = game._cone(details,"Ruota",Vector3(x,.25,z),.24,.12,"#454d44",.24)
                wheel.rotation.z = PI*.5
    elif area == 1:
        for at in [Vector3(-12,0,0),Vector3(12,0,0)]:
            _table(game,details,at,"#70877e")
            game._box(details,"Utensili",at+Vector3(.3,1.0,0),Vector3(.5,.15,.4),"#d3ba77")
        for x in [-8,8]:
            for j in range(3):
                game._cone(details,"Fusto",Vector3(x,.45,8-j*1.0),.35,.9,"#7e9488",.35)
                game._cone(details,"Bordo_fusto",Vector3(x,.88,8-j*1.0),.38,.08,"#b1baa4",.38)
        for z in [-7,-5,-3]: game._box(details,"Canalina",Vector3(4,.035,z),Vector3(.22,.05,1.8),"#545f53")
        game._box(details,"Ricambi_meccanici",Vector3(0,.4,7),Vector3(1.8,.8,1.0),"#7c8270")
        for i in range(3): game._cone(details,"Valvola",Vector3(-.5+i*.5,.9,7),.18,.12,"#c9a75e",.18)
    else:
        for at in [Vector3(-10,0,-1),Vector3(10,0,0)]:
            _table(game,details,at,"#9d9475")
            game._box(details,"Strumento",at+Vector3(0,1.15,0),Vector3(.8,.4,.5),"#677e7d")
            game._box(details,"Schermo",at+Vector3(0,1.18,.27),Vector3(.55,.22,.03),"#a1ba9e")
        for x in [-5,5]:
            for z in [-9,8]:
                game._box(details,"Cavalletto",Vector3(x,.6,z),Vector3(.12,1.2,.12),"#a58d58")
                game._cone(details,"Segnalatore",Vector3(x,1.25,z),.13,.2,"#edc774",.09)
        for i in range(4):
            var tarp = game._box(details,"Copertura_materiali",Vector3(-5+i*.3,.25,9),Vector3(.25,.4,2),"#697d70")
            tarp.rotation.z = .1
        _crate(game,details,Vector3(4,0,-12))
    # Ogni luogo ha un cartello di ingresso, senza anticipare contenuti narrativi.
    game._box(details,"Palo_cartello",Vector3(-2.4,.8,11),Vector3(.12,1.6,.12),"#7b6345")
    game._box(details,"Cartello_ingresso",Vector3(-2.4,1.5,11),Vector3(1.1,.65,.1),"#bca46c")

func _task_clearance(at: Vector3) -> float:
    var distance := INF
    for goal in [Vector3(0,0,11),Vector3(-10,0,5),Vector3(10,0,-6),Vector3(0,0,-10),Vector3(-10,0,-7),Vector3(10,0,6)]:
        distance = minf(distance,at.distance_to(goal))
    return distance
func _pallet(game, parent: Node3D, at: Vector3) -> void:
    for i in range(5): game._box(parent,"Listello_pallet",at+Vector3(-.65+i*.32,.12,0),Vector3(.26,.16,1.5),"#a48b5b")
func _crate(game, parent: Node3D, at: Vector3, size: float = 1.0) -> void:
    game._box(parent,"Cassa_ambiente",at+Vector3(0,.4*size,0),Vector3(1,.8,.85)*size,"#987a50")
    for x in [-.35,.35]: game._box(parent,"Fascia_cassa",at+Vector3(x*size,.42*size,0),Vector3(.09,.86,.9)*size,"#665d43")
func _table(game, parent: Node3D, at: Vector3, color: String) -> void:
    game._box(parent,"Piano_lavoro",at+Vector3(0,.9,0),Vector3(1.8,.12,.9),color)
    for x in [-.7,.7]:
        for z in [-.3,.3]: game._box(parent,"Gamba",at+Vector3(x,.45,z),Vector3(.12,.9,.12),"#645d44")
