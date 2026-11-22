extends Node3D
## Recupero non narrativo: scorta breve, rischio sul carico, progetto permanente.
const START := Vector3(15,.12,15)
const MAX_HP := 120.0
var game
var cart: CharacterBody3D
var hint: Label3D
var health: Label3D
var active := false
var blueprint := false
var hp := MAX_HP
var completions := 0
var ready_at := 0.0
var travelled := 0.0
var ambushes := 0

func configure(world) -> void:
    game = world
    cart = CharacterBody3D.new()
    cart.name = "Carretto_recupero"
    cart.collision_layer = 0
    cart.collision_mask = 1
    add_child(cart)
    cart.position = START
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.0,.7,1.2)
    shape.shape = box
    shape.position.y = .65
    cart.add_child(shape)
    game._box(cart,"Pianale",Vector3(0,.65,0),Vector3(1.3,.18,1.6),"#775239")
    game._box(cart,"Cassa_materiali",Vector3(0,1,0),Vector3(1.05,.6,1.1),"#b38b52")
    for x in [-.46,.46]:
        game._box(cart,"Stanga",Vector3(x,.57,-1.15),Vector3(.10,.12,1.1),"#775239")
        game._box(cart,"Fascia_cassa",Vector3(x,1.02,0),Vector3(.08,.65,1.14),"#6a5439")
    for x in [-.7,.7]:
        for z in [-.52,.52]:
            var wheel: MeshInstance3D = game._cone(cart,"Ruota",Vector3(x,.4,z),.33,.16,"#493c32",.33)
            wheel.rotation.z = PI*.5
    hint = Label3D.new()
    hint.position.y = 2.25
    hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    hint.font_size = 28
    hint.pixel_size = .009
    hint.outline_size = 6
    cart.add_child(hint)
    health = Label3D.new()
    health.position.y = 1.8
    health.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    health.pixel_size = .009
    health.font_size = 24
    cart.add_child(health)
    game._register_occluders(cart)

func interact() -> bool:
    if game.paused or game.hero.global_position.distance_to(cart.global_position) > 2.8:
        return false
    if active:
        game.show_message("Il carretto segue a passo lento entro 3,8 metri. Portalo davanti al cancello.",4.0)
    elif not game.stockade_built:
        game.show_message("Costruisci prima la palizzata per ricevere il carico.",3.0)
    elif game.elapsed < ready_at:
        game.show_message("Nuovo carico disponibile tra %d secondi." % ceili(ready_at-game.elapsed),2.0)
    else:
        active = true
        hp = MAX_HP
        travelled = 0.0
        ambushes = 0
        game.show_message("SCORTA IL CARRETTO al cancello. Resta vicino e proteggilo dagli zombie.",5.0)
        game._save_progress()
    return true

func _physics_process(delta: float) -> void:
    if game == null or game.paused:
        return
    var near: bool = game.hero.global_position.distance_to(cart.global_position) < 8.0
    hint.visible = near
    health.visible = active and near
    health.text = "CARICO %d/%d" % [ceili(hp),int(MAX_HP)]
    hint.text = "F: SCORTA CARRETTO" if not active else "VERSO IL CANCELLO - RESTA VICINO"
    if not active:
        if game.elapsed < ready_at: hint.text = "CARICO IN PREPARAZIONE: %ds" % ceili(ready_at-game.elapsed)
        return
    _advance(delta)

func _advance(delta: float) -> void:
    if not active or game.paused:
        return
    var direction: Vector3 = game.hero.global_position-cart.global_position
    direction.y = 0.0
    cart.velocity = Vector3.ZERO
    if direction.length() > 1.6 and direction.length() < 3.8:
        cart.velocity = direction.normalized()*2.0
    cart.velocity.y = -.5
    var before: Vector3 = cart.global_position
    cart.move_and_slide()
    travelled += Vector2(cart.global_position.x-before.x,cart.global_position.z-before.z).length()
    # Un solo gruppo per soglia: il contatore viene salvato insieme alla missione.
    if ambushes < 2 and travelled >= 4.0+float(ambushes)*8.0:
        ambushes += 1
        for i in range(2):
            if game.enemies.size() < 28:
                var at: Vector3 = cart.global_position+Vector3(4.5 if i == 0 else -4.5,0,4.5)
                at.x = clampf(at.x,-19,19)
                at.z = clampf(at.z,-19,19)
                game._spawn_enemy(at,"normal",false)
        game.show_message("Il carico ha attirato degli zombie!",2.5)
        game._save_progress()
    var destination := Vector3(0,cart.global_position.y,game.gate_front_z()+2.0)
    if cart.global_position.distance_to(destination) < 2.0:
        _deliver()

func target_available(from: Vector3) -> bool:
    return active and hp > 0.0 and from.distance_to(cart.global_position) < 9.0 and game.has_clear_path(from,cart.global_position)

func damage(amount: float) -> void:
    if not active or game.paused:
        return
    hp = maxf(0.0,hp-amount)
    if hp <= 0.0: fail()

func fail() -> void:
    if not active: return
    active = false
    hp = MAX_HP
    ready_at = game.elapsed+60.0
    cart.global_position = START
    game.show_message("Carico perso. Potrai riprovare tra un minuto; il progetto gia ottenuto resta disponibile.",4.0)
    game._save_progress()

func _deliver() -> void:
    if not active: return
    active = false
    completions += 1
    blueprint = true
    ready_at = game.elapsed+600.0
    game.wood += 35
    game.coins += 25
    cart.global_position = START
    game.show_message("CARICO CONSEGNATO! +35 legno, +25 monete. Ampliamento del cortile disponibile al banco (E).",6.0)
    game._save_progress()

func objective_text() -> String:
    if active: return "SCORTA: CARICO %d/%d - CANCELLO A SUD" % [ceili(hp),int(MAX_HP)]
    if not blueprint: return "AMPLIAMENTO: RECUPERA IL CARRETTO A SUD-EST (F)"
    if game.base_level < 2: return "AMPLIAMENTO AL BANCO: 120 LEGNO + 60 MONETE"
    return "CORTILE AMPLIATO | SCORTA DISPONIBILE" if game.elapsed >= ready_at else "CORTILE AMPLIATO"

func save_data() -> Dictionary:
    return {"active":active,"blueprint":blueprint,"hp":hp,"completions":completions,"ready_at":ready_at,"travelled":travelled,"ambushes":ambushes,"x":cart.position.x,"z":cart.position.z}

func load_data(data) -> void:
    if not data is Dictionary: return
    blueprint = bool(data.get("blueprint",false))
    completions = maxi(0,int(data.get("completions",0)))
    ready_at = maxf(0.0,float(data.get("ready_at",0)))
    active = bool(data.get("active",false))
    hp = clampf(float(data.get("hp",MAX_HP)),1.0,MAX_HP)
    travelled = maxf(0.0,float(data.get("travelled",0)))
    ambushes = clampi(int(data.get("ambushes",0)),0,2)
    cart.position = Vector3(clampf(float(data.get("x",START.x)),-19,19),START.y,clampf(float(data.get("z",START.z)),-19,19)) if active else START
