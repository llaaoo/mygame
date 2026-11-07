class_name ExpeditionEquipment
extends RefCounted
var game: CampaignGame

func _init(owner_game: CampaignGame) -> void:
	game = owner_game

func grant(entry: ExplorationDiscoveryData) -> bool:
	var changed := false
	for id in entry.equipment:
		var receipt := "equipment."+entry.id+"."+id
		if not game.catalog.equipment.has(id) or game.progress.claims.has(receipt): continue
		if receive(id,1) == 0: continue # Keep the reward at its source when full.
		game.progress.claims[receipt] = true
		changed = true
	return changed

func restore() -> void:
	if game.player.inventory and game.player.inventory.store:
		_manager()._refresh_from_store()
		return
	var manager := _manager()
	manager.clear_all()
	# Migrate only once: old ownership flags represented already-awarded discoveries.
	if not game.progress.claims.has("equipment.sources_v1"):
		for region: ExplorationRegionData in game.catalog.regions.values():
			for entry in region.discoveries:
				if game.progress.claims.has(entry.id):
					for id in entry.equipment:
						if count(id) > 0: game.progress.claims["equipment."+entry.id+"."+id] = true
		game.progress.claims["equipment.sources_v1"] = true
	for key in game.progress.equipment_loadout:
		var id: String = game.progress.equipment_loadout[key]
		var item := game.catalog.equipment.get(id) as EquipmentData
		if item and count(id) > 0 and key == str(item.slot_type):
			manager.equip(item)
	_reconcile_inventory()
	# Previously read notes can add newly authored items, or retain capacity-blocked ones.
	for region: ExplorationRegionData in game.catalog.regions.values():
		for entry in region.discoveries:
			if game.progress.claims.has(entry.id): grant(entry)

func sync() -> void:
	game.progress.equipment_loadout.clear()
	for item in _manager().get_all_equipped():
		if game.catalog.equipment.has(item.id) and game.progress.equipment_owned.get(item.id, false):
			game.progress.equipment_loadout[str(item.slot_type)] = item.id

func equip(id: String,uid := "") -> bool:
	if not change_reason().is_empty() or count(id) <= 0 or not game.catalog.equipment.has(id):
		return false
	if not _fits_loadout(game.catalog.equipment[id].slot_type,game.catalog.equipment[id]): return false
	if not uid.is_empty() and game.player.inventory.store:
		var store:=game.player.inventory.store
		var item:=store.item(uid)
		if not item or item.definition_id!=id or not store.locate(uid).begins_with("player."): return false
		if not store.equip("player",uid).accepted: return false
		game._save_progress()
		return true
	if not _manager().equip(game.catalog.equipment[id]):
		return false
	_reconcile_inventory()
	game._save_progress()
	return true

func unequip(slot: int) -> bool:
	if not change_reason().is_empty() or not _fits_loadout(slot) or not _manager().unequip(slot):
		return false
	_reconcile_inventory()
	game._save_progress()
	return true

func count(id: String) -> int:
	if game.player.inventory and game.player.inventory.store: return game.player.inventory.store.count("player",id,true)
	return int(game.progress.equipment_counts.get(id,1 if game.progress.equipment_owned.get(id,false) else 0))

func has_pending_rewards(entry: ExplorationDiscoveryData) -> bool:
	for id in entry.equipment:
		if game.catalog.equipment.has(id) and not game.progress.claims.has("equipment."+entry.id+"."+id): return true
	return false

func receive(id: String, amount: int) -> int:
	var item := game.catalog.equipment.get(id) as EquipmentData
	if not item or amount <= 0 or not game.player.inventory: return 0
	var accepted := game.player.inventory.add_item(item,mini(amount,999-count(id)))
	if accepted > 0:
		game.progress.equipment_counts[id] = count(id) if game.player.inventory.store else count(id)+accepted
		game.progress.equipment_owned[id] = true
	return accepted

func _fits_loadout(slot: int, candidate: EquipmentData = null) -> bool:
	var inventory := game.player.inventory
	if not inventory: return false
	var projected := Inventory.new()
	projected.capacity = inventory.capacity
	for i in range(inventory.capacity):
		var entry := inventory.get_slot(i)
		if entry.item and (not entry.item is EquipmentData or not game.catalog.equipment.has(entry.item.id)):
			if projected.add_item(entry.item,entry.quantity) != entry.quantity: return false
	for id in game.catalog.equipment:
		var item: EquipmentData = game.catalog.equipment[id]
		var active := candidate if item.slot_type == slot else _manager().get_equipment(item.slot_type)
		var quantity := maxi(0,count(id)-(1 if active and active.id == id else 0))
		if projected.add_item(item,quantity) != quantity: return false
	return true

func _reconcile_inventory() -> void:
	if game.player.inventory and game.player.inventory.store: return
	var inventory := game.player.inventory
	if not inventory: return
	for item: EquipmentData in game.catalog.equipment.values():
		inventory.remove_item(item,inventory.get_item_count(item))
	for id in game.catalog.equipment:
		var item: EquipmentData = game.catalog.equipment[id]
		var active := _manager().get_equipment(item.slot_type)
		var quantity := maxi(0,count(id)-(1 if active and active.id == id else 0))
		inventory.add_item(item,quantity)

func manager() -> EquipmentManager:
	return _manager()

func _manager() -> EquipmentManager:
	return game.player.get_node("EquipmentManager") as EquipmentManager

func show_equipment() -> void:
	if game.session and game.session.equipment_page.is_valid():
		game.session.equipment_page.call()
		return
	var text := "在营地整备。装备有明确取舍，同槽只能选择一件；已拥有物品保留，重置遭遇不重复发奖。I背包也可查看装备。\n\n" + build_summary()
	var buttons: Array[Dictionary] = []
	for id in game.catalog.equipment:
		var item: EquipmentData = game.catalog.equipment[id]
		var owned: bool = game.progress.equipment_owned.get(id, false)
		var active := _manager().get_equipment(item.slot_type) == item
		text += "\n%s · %s · %s\n%s\n" % [item.display_name, EquipmentManager.slot_name(item.slot_type), "已装备" if active else ("持有%d件" % count(id) if owned else "未发现"), item.description]
		if not owned:
			for region: ExplorationRegionData in game.catalog.regions.values():
				for entry in region.discoveries:
					if id in entry.equipment:
						text += "线索：%s · %s\n" % [region.title, entry.title]
			for region: ExplorationRegionData in game.catalog.regions.values():
				for encounter in region.encounters:
					if encounter.character:
						for worn in encounter.character.equipment:
							if worn.id == id: text += "线索：%s · %s的实际穿戴\n" % [region.title,encounter.character.title]
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
	var buttons: Array[Dictionary] = [{"title": "卸下" if active else "装备", "disabled": not game.is_at_base() or not game.progress.equipment_owned.get(id, false), "callback": _change.bind(id, active)}, {"title": "返回装备总览", "callback": show_equipment}]
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

func change_reason() -> String:
	if game.rules.field_equipment:
		if game.player.health_component.is_dead or game.player.field_work.is_busy() or (game.player.actor_context and game.player.actor_context.actions.busy()) or game.player.skill_manager.combinations.is_busy() or not game.player.casting.aiming_sources.is_empty(): return "先结束当前动作，再手动换装。"
		return "附近有敌人，先脱离战斗再换装。" if game.has_hostiles_near(game.player.position) else ""
	return "返回营地整备。" if not game.is_at_base() else ""
