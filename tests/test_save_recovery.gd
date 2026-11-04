extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []

class FaultRepository extends SaveRepository:
	var fail_at := ""
	func _write_file(path: String, data: Dictionary) -> Error:
		return ERR_CANT_CREATE if fail_at == "write" else super._write_file(path, data)
	func _copy_file(source: String, destination: String) -> Error:
		return ERR_CANT_CREATE if fail_at == "copy" else super._copy_file(source, destination)
	func _replace_file(source: String, destination: String) -> Error:
		if (fail_at == "backup" and destination.ends_with(".bak")) or (fail_at == "replace" and not destination.ends_with(".bak")):
			return ERR_CANT_CREATE
		return super._replace_file(source, destination)

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _payload(id: String) -> Dictionary:
	var root := SaveData.Root.new()
	root.meta = SaveData.MetaData.new()
	root.player = SaveData.PlayerData.new()
	root.world = SaveData.WorldData.new()
	root.quest = SaveData.QuestSave.new()
	var progress := ExplorationProgress.new()
	progress.claim(id, id, "Knowledge survives recovery.", ["fire_sigil"], ["fire_sigil_fireball"])
	root.extensions = {MVPGame.SECTION: progress.serialize_save_data()}
	return root.serialize()

func _raw(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(value)
	file.close()

func _run() -> void:
	var repo := SaveRepository.new()
	var progress := ExplorationProgress.new()
	repo.section_validators[MVPGame.SECTION] = progress.validate_save_data
	var path := "user://repository-test.sav"
	_check(repo.read(path).status == SaveRepository.Status.MISSING, "Missing file was treated as damaged")
	var a := _payload("knowledge.a")
	var b := _payload("knowledge.b")
	_check(repo.write(path, a) and repo.read(path).data == a, "Valid file did not round-trip")
	_check(repo.write(path, b) and repo.read(path + ".bak").data == a, "Valid primary was not backed up")
	_raw(path, "broken primary")
	_check(repo.read(path).status == SaveRepository.Status.RECOVERED and repo.read(path).data == a, "Backup recovery failed")
	var backup := FileAccess.get_file_as_bytes(path + ".bak")
	_check(repo.write(path, b) and FileAccess.get_file_as_bytes(path + ".bak") == backup, "Recovery overwrote the valid backup with a damaged primary")
	for invalid_version in [{}, [], "three", null, 3.5]:
		var malformed := a.duplicate(true)
		malformed.version = invalid_version
		_raw(path, malformed)
		_check(repo.read(path).status == SaveRepository.Status.RECOVERED and repo.migrate(malformed).is_empty(), "Malformed version bypassed validation or prevented backup recovery")
	var future := a.duplicate(true)
	future.version = SaveRepository.VERSION + 1
	_raw(path, future)
	var original := FileAccess.get_file_as_bytes(path)
	_check(repo.read(path).status == SaveRepository.Status.UNSUPPORTED_VERSION and not repo.write(path, b), "Future version was silently downgraded")
	_check(FileAccess.get_file_as_bytes(path) == original and FileAccess.get_file_as_bytes(path + ".bak") == backup, "Unsupported files were modified")
	_raw(path, {"version": SaveRepository.VERSION + 1, "new_schema": true})
	_check(repo.read(path).status == SaveRepository.Status.UNSUPPORTED_VERSION and not repo.write(path, b), "Future schema was mistaken for corruption and downgraded")
	_raw(path, a)
	_raw(path + ".bak", future)
	_check(not repo.write(path, b), "Newer backup was overwritten by an older runtime")
	_raw(path, "broken")
	_raw(path + ".bak", "also broken")
	original = FileAccess.get_file_as_bytes(path)
	_check(repo.read(path).status == SaveRepository.Status.INVALID and not repo.write(path, a), "Damaged files accepted automatic overwrite")
	_check(FileAccess.get_file_as_bytes(path) == original, "Damaged primary changed")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_32(500)
	file.store_8(1)
	file.close()
	_check(repo.read(path).status == SaveRepository.Status.INVALID, "Truncated file envelope was accepted")
	var malformed := a.duplicate(true)
	malformed.extensions[MVPGame.SECTION].cleared = []
	_raw(path, malformed)
	_raw(path + ".bak", a)
	_check(repo.read(path).status == SaveRepository.Status.RECOVERED, "Malformed progress section was not rejected")
	malformed = a.duplicate(true)
	malformed.extensions[MVPGame.SECTION].character_state = {"stats": {"strength": {"wrong": "type"}}}
	_raw(path, malformed)
	_check(repo.read(path).status == SaveRepository.Status.RECOVERED, "Malformed character numbers were accepted")
	var v1 := a.duplicate(true)
	v1.version = 1
	v1.erase("extensions")
	v1.player.erase("equipment_items")
	_raw(path, v1)
	_check(repo.read(path).data.version == SaveRepository.VERSION and repo.read(path).data.player.has("equipment_items"), "Legacy migration changed")

	for failure in ["write", "copy", "backup", "replace"]:
		var fault := FaultRepository.new()
		var fault_path := "user://fault-%s.sav" % failure
		_check(fault.write(fault_path, a) and fault.write(fault_path, b), "Fault setup failed")
		var before := FileAccess.get_file_as_bytes(fault_path)
		fault.fail_at = failure
		_check(not fault.write(fault_path, a) and FileAccess.get_file_as_bytes(fault_path) == before, "Failed %s damaged primary" % failure)
		_check(fault.read(fault_path).usable(), "Failed %s left no readable state" % failure)

	# Exercise the actual bootstrap and its automatic save, not only repository helpers.
	_raw("user://save_2.sav", "broken primary")
	_raw("user://save_2.sav.bak", a)
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot(true)
	_check(game.progress.claims.has("knowledge.a") and game.player.skill_manager.known_actions.has("fire_sigil"), "Fresh game did not restore knowledge from backup")
	_check(repo.read("user://save_2.sav.bak").data == a, "Bootstrap destroyed recovered backup")
	await fixture.close()
	_raw("user://save_2.sav", "broken primary")
	_raw("user://save_2.sav.bak", "broken backup")
	original = FileAccess.get_file_as_bytes("user://save_2.sav")
	backup = FileAccess.get_file_as_bytes("user://save_2.sav.bak")
	game = await fixture.boot(true)
	_check(game._save_dirty, "Failed save discarded dirty state")
	game.progress.claim("memory.only", "memory", "Keep unsaved progress", [], [])
	game.reload_progress()
	_check(game.progress.claims.has("memory.only"), "Failed reload discarded live progress")
	_check(not SaveManager.instance.save_game(2), "F5-style save overwrote damaged files")
	_check(FileAccess.get_file_as_bytes("user://save_2.sav") == original and FileAccess.get_file_as_bytes("user://save_2.sav.bak") == backup, "Damaged files changed during bootstrap/reload/save")
	await fixture.close()
	if failures.is_empty():
		print("Save recovery passed: backup, future versions, malformed/truncated files, I/O failures, legacy migration and real bootstrap/reload")
	quit(0 if failures.is_empty() else 1)
