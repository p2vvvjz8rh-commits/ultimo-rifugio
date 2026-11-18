extends CanvasLayer
## Due canali indipendenti: il bottino non puo cancellare gli avvisi di difesa.
var game
var raid_label: Label
var defense_label: Label
var raid_until := 0.0
var defense_until := 0.0
var warned_raid := -1.0
var last_defense := -100.0
var zones: Array[String] = []
var presentations := 0
func configure(world) -> void:
    game = world
    layer = 40
    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER_TOP)
    box.offset_left = -280
    box.offset_right = 280
    box.offset_top = 132
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(box)
    for i in range(2):
        var label := Label.new()
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size",21 if i == 0 else 18)
        label.add_theme_color_override("font_color",Color("#ffdf8b") if i == 0 else Color("#ffb8a4"))
        label.add_theme_color_override("font_shadow_color",Color.BLACK)
        label.add_theme_constant_override("shadow_outline_size",6)
        label.add_theme_color_override("font_outline_color",Color("#251a18"))
        label.add_theme_constant_override("outline_size",8)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        box.add_child(label)
        if i == 0: raid_label = label
        else: defense_label = label
func tick() -> void:
    if game.paused: return
    if game.next_raid-game.elapsed <= 20 and warned_raid != game.next_raid:
        warned_raid = game.next_raid
        raid_label.text = "ORDA IN ARRIVO - TORNA A PREPARARE LE DIFESE"
        raid_until = game.elapsed+7
    raid_label.visible = game.elapsed < raid_until
    defense_label.visible = game.elapsed < defense_until
    if game.elapsed >= defense_until: zones.clear()
func raid_started(number: int) -> void:
    raid_label.text = "ORDA %d IN AVVICINAMENTO ALLA BASE" % number
    raid_until = game.elapsed+8
    raid_label.visible = true
func attacked(zone: String, broken: bool = false) -> void:
    if game.elapsed >= defense_until: zones.clear()
    if not zones.has(zone): zones.append(zone)
    defense_label.text = ("BRECCIA! " if broken else "DIFESE SOTTO ATTACCO: ") + ", ".join(zones)
    # I colpi aggiornano le zone ma non riavviano continuamente la notifica.
    if broken or game.elapsed-last_defense >= 8:
        last_defense = game.elapsed
        defense_until = game.elapsed+6
        defense_label.visible = true
        presentations += 1
