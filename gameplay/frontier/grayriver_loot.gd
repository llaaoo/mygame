class_name GrayriverLoot
extends RefCounted
## Persistent remainder ledger. No loot rolls and no refills from a character template.
var game: GrayriverGame
var corpses: Dictionary = {}

func _init(owner_game: GrayriverGame) -> void: game = owner_game

static func snapshot(enemy: Enemy) -> Dictionary:
	var equipment := {}
	var manager := enemy.get_node_or_null("EquipmentManager") as EquipmentManager
	if manager:
		for item in manager.get_all_equipped(): equipment[item.id] = int(equipment.get(item.id, 0)) + 1
	var materials := {}
	if enemy.skill_manager and enemy.skill_manager.combinations:
		for id in enemy.skill_manager.combinations.supplies.amounts:
			var amount := enemy.skill_manager.combinations.supplies.count(id)
			if amount > 0: materials[id] = amount
	return {"equipment": equipment, "materials": materials}

func record_enemy(enemy: Enemy) -> void:
	if game.practice_active or not enemy.rewards_enabled: return
	var id := str(enemy.get_meta("frontier_claim", ""))
	if id.is_empty() or game.progress.loot_records.has(id): return
	var record := snapshot(enemy)
	record.merge({"region":game.region_id, "position":[enemy.position.x,enemy.position.y], "title":enemy.enemy_name+"的遗骸"})
	# Keep even empty records as tombstones: an encounter reset cannot mint equipment.
	game.progress.loot_records[id] = record
	_mount(id)

func mount_region() -> void:
	corpses.clear()
	for id in game.progress.loot_records:
		if game.progress.loot_records[id].region == game.region_id: _mount(id)

func _mount(id: String) -> void:
	if corpses.has(id) and is_instance_valid(corpses[id]): return
	var record: Dictionary = game.progress.loot_records[id]
	var corpse := GrayriverLootCorpse.new()
	corpse.service = self
	corpse.loot_id = id
	corpse.position = GrayriverDefinition.vector(record.position)
	game.region_root.add_child(corpse)
	corpses[id] = corpse

func _available(id: String) -> bool:
	if game._switching or game.player.health_component.is_dead or not game.progress.loot_records.has(id): return false
	var corpse := corpses.get(id) as GrayriverLootCorpse
	return is_instance_valid(corpse) and corpse.get_parent() == game.region_root and game.player.global_position.distance_to(corpse.global_position) < PlayerInputController.INTERACT_RANGE

func inspect(id: String) -> void:
	if not _available(id): return
	var record: Dictionary = game.progress.loot_records[id]
	var text := "物品来自死者实际穿戴与剩余行囊。已消耗的材料不会再出现；未取走的东西会留在这里。\n\n"
	var buttons: Array[Dictionary] = []
	for item_id in record.equipment:
		var item := game.catalog.equipment.get(item_id) as EquipmentData
		if not item: continue
		text += "%s ×%d\n%s\n\n" % [item.display_name,record.equipment[item_id],item.description]
		buttons.append({"title":"取走："+item.display_name,"callback":_take_and_show.bind(id,"equipment",item_id)})
	for item_id in record.materials:
		text += "%s ×%d\n" % [game.survival.supplies.title(item_id),record.materials[item_id]]
		buttons.append({"title":"取走："+game.survival.supplies.title(item_id),"callback":_take_and_show.bind(id,"materials",item_id)})
	if buttons.is_empty(): text += "已经没有可取走的物品。"
	else: buttons.push_front({"title":"尽量全部取走","callback":_take_and_show.bind(id,"","")})
	buttons.append({"title":"留下物品，继续探索","callback":game.ui.close_modal})
	game.ui.show_panel(record.title,text,buttons)

func _take_and_show(id: String, kind: String, item: String) -> void:
	var taken := take(id,kind,item)
	inspect(id)
	game.ui.notify("已收好战利品；容量不足的物品留在原地。" if taken > 0 else "未取走物品：背包或水囊已满，或已不在遗骸附近。")

func take(id: String, kind := "", item_id := "") -> int:
	if not _available(id) or kind not in ["","equipment","materials"]: return 0
	var record: Dictionary = game.progress.loot_records[id]
	var taken := 0
	for category in ["equipment","materials"]:
		if not kind.is_empty() and kind != category: continue
		var entries: Dictionary = record[category]
		for key in entries.keys():
			if not item_id.is_empty() and key != item_id: continue
			var amount := int(entries[key])
			var added := 0
			if category == "equipment":
				added = game.equipment_service.receive(key,amount)
			else:
				var supplies := game.survival.supplies
				var before := supplies.count(key)
				supplies.grant({key:amount})
				added = supplies.count(key)-before
			if added == 0: continue
			taken += added
			if amount == added: entries.erase(key)
			else: entries[key] = amount-added
	if taken > 0:
		game.progress.claims["loot."+id] = true
		(corpses[id] as GrayriverLootCorpse).refresh()
		game._save_progress()
	return taken

func inspect_actor(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy.health_component.is_dead or enemy.global_position.distance_to(game.player.global_position) >= PlayerInputController.INTERACT_RANGE: return
	var carried := snapshot(enemy)
	var text := "穿戴与行囊读取当前实物，击败后回收这些装备及尚未用掉的物资。\n\n" if enemy.rewards_enabled else "这是无奖励试战：穿戴仍产生战斗效果，击败后不生成新的战利品。\n\n"
	for id in carried.equipment:
		var item := game.catalog.equipment.get(id) as EquipmentData
		if item: text += item.display_name+"\n"+item.description+"\n\n"
	for id in carried.materials: text += "%s ×%d\n" % [game.survival.supplies.title(id),carried.materials[id]]
	text += "\n生命 %d/%d · 法力 %d/%d · 近战 %d" % [enemy.health_component.hp,enemy.health_component.max_hp,enemy.mana_component.mp if enemy.mana_component else 0,enemy.mana_component.max_mp if enemy.mana_component else 0,enemy.attack_damage]
	game.ui.show_panel(enemy.enemy_name+" · 观察",text,[{"title":"继续行动","callback":game.ui.close_modal}])

static func valid_records(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 512: return false
	for id in value:
		var record = value[id]
		if not id is String or not id.begins_with("river.enemy.") or not record is Dictionary: return false
		if record.get("region", "") not in ["camp","river_archive","river_mine","river_prison"] or not record.get("title") is String: return false
		var point = record.get("position")
		if not point is Array or point.size() != 2: return false
		for n in point:
			if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or absf(float(n)) > 100000: return false
		for kind in ["equipment","materials"]:
			if not record.get(kind) is Dictionary: return false
			for key in record[kind]:
				if not key is String or not record[kind][key] is int or record[kind][key] <= 0 or record[kind][key] > 999: return false
				if kind == "materials" and not CastingSupplies.known_item(key): return false
				if kind == "equipment" and key not in GrayriverItems.EQUIPMENT_IDS and key not in ["keeper_ring","cadence_gloves","soul_amulet","covenant_ring"]: return false
	return true
