extends SceneTree


func _init() -> void:
	var catalog := EquipmentCatalog.get_all()
	if catalog.size() != 30:
		_fail("equipment catalog expected 30 items, got %d" % catalog.size())
		return

	var ids := {}
	var covered_slots := {}
	for item in catalog:
		if item.id.is_empty() or ids.has(item.id):
			_fail("equipment IDs must be non-empty and unique: %s" % item.id)
			return
		ids[item.id] = true
		covered_slots[item.slot_type] = true
		if not item.get_icon_texture():
			_fail("equipment is missing an icon: %s" % item.id)
			return
		if item.get_effective_power_score() <= 0:
			_fail("equipment power score must be positive: %s" % item.id)
			return
	if covered_slots.size() != EquipmentData.SlotType.size():
		_fail("equipment does not cover all slots")
		return

	var main_scene := load("res://main.tscn") as PackedScene
	var game := main_scene.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var player := get_first_node_in_group("player") as Player
	if not player:
		_fail("player was not created")
		return
	var manager := player.get_node("EquipmentManager") as EquipmentManager
	var base_hp := player.health_component.max_hp
	manager.equip(EquipmentCatalog.get_by_id("vanguard_helmet"))
	manager.equip(EquipmentCatalog.get_by_id("vanguard_cuirass"))
	manager.equip(EquipmentCatalog.get_by_id("vanguard_greaves"))
	if player.health_component.max_hp <= base_hp:
		_fail("equipment stat bonuses were not applied")
		return
	if manager.get_modifier_value("damage_reduction") < 0.14:
		_fail("three-piece set bonus was not activated")
		return
	if manager.get_active_set_bonuses().size() != 2:
		_fail("three vanguard pieces should activate two thresholds")
		return
	var equipped_hp := player.health_component.max_hp
	var live_save_manager := SaveManager.new()
	root.add_child(live_save_manager)
	var saved_player := live_save_manager._collect_player()
	manager.clear_all()
	live_save_manager._restore_player(saved_player)
	if manager.get_all_equipped().size() != 3:
		_fail("equipped loadout was not restored from live save data")
		return
	if player.health_component.max_hp != equipped_hp:
		_fail("equipment stats changed after a save restore")
		return
	manager.clear_all()
	if player.health_component.max_hp != base_hp:
		_fail("equipment stat bonuses were not reversible")
		return

	var crown := EquipmentCatalog.get_by_id("sun_crown")
	var chest := (load("res://world/loot/chest.tscn") as PackedScene).instantiate() as Chest
	game.add_child(chest)
	chest._spawn_item(crown.resource_path, 1)
	await process_frame
	var spawned_pickup: ItemPickup
	for child in game.get_children():
		if child is ItemPickup and (child as ItemPickup).item_data == crown:
			spawned_pickup = child
			break
	if not spawned_pickup:
		_fail("chest did not create an equipment pickup")
		return
	spawned_pickup._on_collected(player)
	if player.inventory.get_item_count(crown) != 1:
		_fail("equipment pickup did not enter the inventory")
		return

	var save_root := SaveData.Root.new()
	save_root.meta = SaveData.MetaData.new()
	save_root.player = SaveData.PlayerData.new()
	save_root.player.equipment_items = [{"path": catalog[0].resource_path, "slot": int(catalog[0].slot_type)}]
	save_root.world = SaveData.WorldData.new()
	save_root.quest = SaveData.QuestSave.new()
	var restored := SaveData.Root.deserialize(save_root.serialize())
	if restored.player.equipment_items != save_root.player.equipment_items:
		_fail("equipment save data did not round-trip")
		return

	var migrated := live_save_manager._migrate({"version": 2, "player": {}, "meta": {}, "world": {}, "quest": {}, "extensions": {}})
	if int(migrated.get("version", 0)) != SaveManager.VERSION:
		_fail("v2 save did not migrate")
		return
	if not (migrated.player.get("equipment_items", null) is Array):
		_fail("equipment migration did not initialize equipment_items")
		return

	print("Equipment system tests passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
