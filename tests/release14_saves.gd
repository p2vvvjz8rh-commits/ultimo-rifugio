extends SceneTree
var failures: int = 0
func check(condition: bool, description: String) -> void:
    if not condition:
        failures += 1
        push_error(description)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var previous: String = OS.get_environment("ULTIMO_RIFUGIO_TEST_DATA")
    var directory: String = ProjectSettings.globalize_path("user://release14-test")
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",directory)
    var save_dir: String = directory.path_join("salvataggi")
    DirAccess.make_dir_recursive_absolute(save_dir)
    var path: String = save_dir.path_join("partita.json")
    var legacy: String = JSON.stringify({"version":8,"wood":77,"coins":31,"hp":83,"px":1,"pz":2,"stockade_built":true,"gate_hp":140,"wall_hp":[120],"defense_hp_scale":240})
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string(legacy)
    file.close()
    var game = load("res://scripts/world.gd").new()
    root.add_child(game)
    game.process_mode = Node.PROCESS_MODE_DISABLED
    game.skip_save_on_exit = true
    check(game._save_directory() == save_dir,"Il builder usa una directory esplicita separata dalla partita reale")
    check(game.wood == 77 and game.coins == 31 and game.gate_hp == 140 and game.wall_segments[0]["hp"] == 120,"Dati Alfa 13 caricati integralmente")
    check(FileAccess.get_file_as_string(save_dir.path_join("partita_pre_alfa14.json")) == legacy,"Backup pre Alfa 14 identico prima di scrivere la partita")
    game._save_progress()
    var data = JSON.parse_string(FileAccess.get_file_as_string(path))
    check(data["version"] == 8 and data["game_release"] == "alfa14","Versione JSON conservata con marcatore opzionale")
    var backups: int = DirAccess.get_files_at(save_dir).size()
    game._load_progress()
    check(DirAccess.get_files_at(save_dir).size() == backups,"Nessun nuovo backup dopo la conversione completata")
    game.queue_free()
    await process_frame
    # Se il backup non e' scrivibile, non si deve troncare la partita originale.
    var protected_dir: String = directory.path_join("backup-non-scrivibile")
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",protected_dir)
    var protected_saves: String = protected_dir.path_join("salvataggi")
    DirAccess.make_dir_recursive_absolute(protected_saves.path_join("partita_pre_alfa14.json"))
    var protected_path: String = protected_saves.path_join("partita.json")
    file = FileAccess.open(protected_path,FileAccess.WRITE)
    file.store_string(legacy)
    file.close()
    var protected_game = load("res://scripts/world.gd").new()
    root.add_child(protected_game)
    protected_game.process_mode = Node.PROCESS_MODE_DISABLED
    protected_game.skip_save_on_exit = true
    check(not protected_game.save_backup_ready,"Backup fallito blocca il salvataggio")
    protected_game.wood = 999
    protected_game._save_progress()
    check(FileAccess.get_file_as_string(protected_path) == legacy,"La partita resta intatta se il backup fallisce")
    protected_game.queue_free()
    await process_frame
    OS.set_environment("ULTIMO_RIFUGIO_TEST_DATA",previous)
    print("Pubblicazione Alfa 14 e salvataggi: %d errori" % failures)
    quit(1 if failures else 0)
