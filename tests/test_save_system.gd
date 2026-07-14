extends SceneTree

const RUN_META_SCRIPT := preload("res://gameplay/run/run_meta.gd")


func _init() -> void:
	var manager := SaveManager.new()
	var v1_payload := {
		"version": 1,
		"meta": {},
		"player": {},
		"world": {},
		"quest": {},
	}
	var migrated: Dictionary = manager._migrate(v1_payload)
	if int(migrated.get("version", 0)) != SaveManager.VERSION:
		_fail("v1 save did not migrate to the current version")
		return
	if not (migrated.get("extensions", null) is Dictionary):
		_fail("migration did not create an extensions section")
		return

	var meta = RUN_META_SCRIPT.new()
	meta.cinders = 42
	meta.clears = 3
	meta.vitality_rank = 2
	var root := SaveData.Root.new()
	root.meta = SaveData.MetaData.new()
	root.player = SaveData.PlayerData.new()
	root.player.skill_upgrade_state = {
		"slot_0": {"skill_id": "fireball", "upgrades": {"power": 2, "cadence": 1}},
	}
	root.world = SaveData.WorldData.new()
	root.quest = SaveData.QuestSave.new()
	root.extensions = {"roguelite_meta": meta.serialize_save_data()}
	var restored := SaveData.Root.deserialize(root.serialize())
	if restored.player.skill_upgrade_state != root.player.skill_upgrade_state:
		_fail("skill upgrade state did not round-trip")
		return
	var restored_meta = RUN_META_SCRIPT.new()
	restored_meta.deserialize_save_data(restored.extensions.get("roguelite_meta", {}))
	if restored_meta.cinders != 42 or restored_meta.clears != 3 or restored_meta.vitality_rank != 2:
		_fail("extension data did not round-trip")
		return

	manager.free()
	print("Save system tests passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
