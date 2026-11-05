class_name ExpeditionEquipment
extends RefCounted
var game: MVPGame

func _init(owner_game: MVPGame) -> void:
	game = owner_game

func grant(entry: ExplorationDiscoveryData) -> bool:
	var changed := false
	for id in entry.equipment:
		if game.catalog.equipment.has(id) and not game.progress.equipment_owned.get(id, false):
			game.progress.equipment_owned[id] = true
			changed = true
	if changed:
		_reconcile_inventory()
	return changed

func restore() -> void:
	var manager := _manager()
	manager.clear_all()
	# Previously claimed records also award their newly authored artifact, once.
	for region: ExplorationRegionData in game.catalog.regions.values():
		for entry in region.discoveries:
			if game.progress.claims.has(entry.id):
				grant(entry)
	for key in game.progress.equipment_loadout:
		var id: String = game.progress.equipment_loadout[key]
		var item := game.catalog.equipment.get(id) as EquipmentData
		if item and game.progress.equipment_owned.get(id, false) and key == str(item.slot_type):
			manager.equip(item)
	_reconcile_inventory()

func sync() -> void:
	game.progress.equipment_loadout.clear()
	for item in _manager().get_all_equipped():
		if game.catalog.equipment.has(item.id) and game.progress.equipment_owned.get(item.id, false):
			game.progress.equipment_loadout[str(item.slot_type)] = item.id

func equip(id: String) -> bool:
	if game.region_id != "camp" or not game.progress.equipment_owned.get(id, false) or not game.catalog.equipment.has(id):
		return false
	if not _manager().equip(game.catalog.equipment[id]):
		return false
	_reconcile_inventory()
	game._save_progress()
	return true

func unequip(slot: int) -> bool:
	if game.region_id != "camp" or not _manager().unequip(slot):
		return false
	_reconcile_inventory()
	game._save_progress()
	return true

func _reconcile_inventory() -> void:
	var inventory := game.player.inventory
	if not inventory:
		return
	for item: EquipmentData in game.catalog.equipment.values():
		inventory.remove_item(item, inventory.get_item_count(item))
		if game.progress.equipment_owned.get(item.id, false) and _manager().get_equipment(item.slot_type) != item:
			inventory.add_item(item)

func _manager() -> EquipmentManager:
	return game.player.get_node("EquipmentManager") as EquipmentManager

func show_equipment() -> void:
	var text := "在营地整备。装备有明确取舍，同槽只能选择一件；已拥有物品保留，重置遭遇不重复发奖。I背包也可查看装备。\n\n" + build_summary()
	var buttons: Array[Dictionary] = []
	for id in game.catalog.equipment:
		var item: EquipmentData = game.catalog.equipment[id]
		var owned: bool = game.progress.equipment_owned.get(id, false)
		var active := _manager().get_equipment(item.slot_type) == item
		text += "\n%s · %s · %s\n%s\n" % [item.display_name, EquipmentManager.slot_name(item.slot_type), "已装备" if active else ("已获得" if owned else "未发现"), item.description]
		if not owned:
			for region: ExplorationRegionData in game.catalog.regions.values():
				for entry in region.discoveries:
					if id in entry.equipment:
						text += "线索：%s · %s\n" % [region.title, entry.title]
		buttons.append({"title": item.display_name + (" · 已装备" if active else " · 详情"), "callback": show_detail.bind(id)})
	buttons.append({"title": "继续探索", "callback": game.ui.close_modal})
	game.ui.show_panel("装备与构筑", text, buttons)

func show_detail(id: String) -> void:
	var item := game.catalog.equipment.get(id) as EquipmentData
	if not item:
		return
	var current := _manager().get_equipment(item.slot_type)
	var text := "%s · %s\n%s\n\n当前同槽：%s\n%s" % [item.display_name, EquipmentManager.slot_name(item.slot_type), item.description, current.display_name if current else "空", build_summary()]
	text += "\n装备后预计\n" + build_summary(item)
	var active := current == item
	var buttons: Array[Dictionary] = [{"title": "卸下" if active else "装备", "disabled": game.region_id != "camp" or not game.progress.equipment_owned.get(id, false), "callback": _change.bind(id, active)}, {"title": "返回装备总览", "callback": show_equipment}]
	game.ui.show_panel(item.display_name, text, buttons)

func _change(id: String, active: bool) -> void:
	if active:
		unequip(game.catalog.equipment[id].slot_type)
	else:
		equip(id)
	show_equipment()

func build_summary(candidate: EquipmentData = null) -> String:
	var values: Dictionary = {}
	var previous: EquipmentData = _manager().get_equipment(candidate.slot_type) if candidate else null
	for key in CastingEquipmentProfile.KEYS:
		values[key] = _manager().casting_value(key)
		if candidate:
			values[key] += (float(candidate.casting_profile.get(key)) if candidate.casting_profile else 0.0) - (float(previous.casting_profile.get(key)) if previous and previous.casting_profile else 0.0)
	var text := "布阵：半径%.0f / %.0f秒（材料另计）\n魂术：容量%d / 汲魂范围%.0f\n条件准备：×%.2f\n恩赐释放：伤害倍率额外%+.2f / 每份额外%+d MP\n可释放恩赐时长：×%.2f\n" % [clampf(96 + values.field_radius_bonus, 48, 180), clampf(15 + values.field_duration_bonus, 5, 40), maxi(1, 3 + int(values.soul_capacity_bonus)), 150 + values.soul_range_bonus, clampf(1 + values.preparation_bonus, 0.5, 1.5), values.empower_damage_bonus, int(values.empower_mana_bonus), maxf(0.25, 1 + values.boon_duration_bonus)]
	var infusion_cost := _manager().medium_infusion_cost(candidate)
	text += "介质灌注：Shift造地借用最新可反应法阵，1次充能 + %d MP（费用修正前）\n" % infusion_cost if infusion_cost >= 0 else "介质灌注：未启用\n"
	var partial_cost := _manager().partial_boon_cost(candidate)
	text += "恩赐消费：Shift保留剩余时长50%%，改用保留伤害倍率；形态强化保留，每份再加%d MP（费用修正前）\n" % partial_cost if partial_cost >= 0 else "恩赐消费：Shift完整消费，获得完整释放倍率\n"
	return text
