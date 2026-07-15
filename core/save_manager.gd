class_name SaveManager
extends Node

const VERSION: int = 3

static var instance: SaveManager

var active_slot: int = 1
var _sections: Dictionary = {}


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if instance == self:
		instance = null


func register_section(section_id: String, provider: Variant) -> void:
	if section_id.is_empty() or provider == null:
		return
	if not provider.has_method("serialize_save_data") or not provider.has_method("deserialize_save_data"):
		push_warning("SaveManager: section '%s' is missing persistence methods." % section_id)
		return
	_sections[section_id] = provider


func unregister_section(section_id: String) -> void:
	_sections.erase(section_id)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_F5:
		save_game(1)
	elif event.keycode == KEY_F9:
		load_game(1)


func save_game(slot: int) -> void:
	active_slot = slot
	var root := SaveData.Root.new()
	root.meta = _collect_meta()
	root.player = _collect_player()
	root.world = _collect_world()
	root.quest = _collect_quests()
	root.extensions = _collect_extensions()

	var data: Dictionary = root.serialize()
	var path := _path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: failed to write %s" % path)
		return
	file.store_var(data, true)
	file.close()
	print("SaveManager: saved %s" % path)


func load_game(slot: int) -> void:
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		print("SaveManager: missing save %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var data: Variant = file.get_var(true)
	file.close()
	if not (data is Dictionary):
		push_error("SaveManager: corrupted save data")
		return

	var raw := _migrate(data as Dictionary)
	if raw.is_empty():
		return

	_cleanup_transient()

	var root := SaveData.Root.deserialize(raw)
	_restore_world(root.world)
	await _restore_region(root.meta)
	_restore_player(root.player)
	_restore_quests(root.quest)
	_restore_extensions(root.extensions)
	print("SaveManager: loaded %s" % path)


func _cleanup_transient() -> void:
	for proj in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(proj):
			proj.queue_free()

	var player := _get_player()
	if player:
		player.set_process(true)
		player.set_physics_process(true)
		if player.health_component:
			player.health_component.is_dead = false
		if player.summon_manager:
			player.summon_manager.clear_all()

	if CombatExecutor.instance:
		CombatExecutor.instance.enter_phase(CombatPhase.Phase.IDLE)
		CombatExecutor.instance.reset_chain()


func _collect_meta() -> SaveData.MetaData:
	var meta := SaveData.MetaData.new()
	meta.timestamp = Time.get_unix_time_from_system()
	var player := _get_player()
	if player and player.stats_component:
		meta.player_level = player.stats_component.level
	var gr := GameRuntime.instance
	if gr and gr.get_region_runtime():
		meta.region_id = gr.get_region_runtime().get_current_region_path()
	return meta


func _collect_player() -> SaveData.PlayerData:
	var p := SaveData.PlayerData.new()
	var player := _get_player()
	if not player:
		return p

	p.position = player.global_position
	if player.health_component:
		p.hp = player.health_component.hp
		p.max_hp = player.health_component.max_hp
	if player.mana_component:
		p.mp = player.mana_component.mp
		p.max_mp = player.mana_component.max_mp
	var equipment := player.get_node_or_null("EquipmentManager") as EquipmentManager
	if equipment:
		p.max_hp -= int(equipment.get_applied_stat_modifier("max_hp"))
		p.max_mp -= int(equipment.get_applied_stat_modifier("max_mana"))

	var sc := player.stats_component
	if sc:
		p.level = sc.level
		p.experience = sc.experience
		p.exp_to_next = sc.exp_to_next
		p.attribute_points = sc.attribute_points
		p.strength = sc.strength
		p.intelligence = sc.intelligence
		p.agility = sc.agility
		p.endurance = sc.endurance

	if player.inventory:
		for i: int in range(player.inventory.capacity):
			var slot: Dictionary = player.inventory.get_slot(i)
			if slot.item:
				p.inventory_items.append({
					"path": slot.item.resource_path,
					"quantity": slot.quantity,
					"slot": i,
				})
	if equipment:
		for item in equipment.get_all_equipped():
			if item and not item.resource_path.is_empty():
				p.equipment_items.append({"path": item.resource_path, "slot": int(item.slot_type)})

	var sm := player.skill_manager as SkillManager
	if sm:
		if sm.left_hand and sm.left_hand.data:
			p.skill_left = sm.left_hand.data.get_id()
		if sm.right_hand and sm.right_hand.data:
			p.skill_right = sm.right_hand.data.get_id()
		p.skill_slots.resize(6)
		for i: int in range(6):
			var inst: SkillInstance = sm.get_slot(i)
			p.skill_slots[i] = inst.data.get_id() if inst and inst.data else ""
		p.skill_cooldowns.clear()
		if sm.left_hand:
			p.skill_cooldowns["left"] = sm.left_hand.current_cooldown
		if sm.right_hand:
			p.skill_cooldowns["right"] = sm.right_hand.current_cooldown
		for i: int in range(6):
			var slot_inst: SkillInstance = sm.get_slot(i)
			if slot_inst:
				p.skill_cooldowns["slot_%d" % i] = slot_inst.current_cooldown
		p.skill_upgrade_state = sm.serialize_skill_state()
	if player.mastery_manager:
		p.mastery_state = player.mastery_manager.serialize_state()
	var buff_manager := player.get_node_or_null("BuffManager") as BuffManager
	if buff_manager:
		p.buff_state = buff_manager.serialize_state()
	return p


func _collect_world() -> SaveData.WorldData:
	var world := SaveData.WorldData.new()
	var gr := GameRuntime.instance
	if gr and gr.world_runtime:
		world.object_states = gr.world_runtime.state_manager.get_all_states()
	if WorldTime.instance:
		world.world_time_hour = WorldTime.instance.hour
	return world


func _collect_quests() -> SaveData.QuestSave:
	var q := SaveData.QuestSave.new()
	var player := _get_player()
	if not player:
		return q
	var qm: QuestManager = player.get("quest_manager")
	if qm:
		q.completed = qm.get_completed_quests()
		q.active = qm.get_active_quest_states()
	return q


func _collect_extensions() -> Dictionary:
	var data: Dictionary = {}
	for section_id: String in _sections:
		var provider: Variant = _sections[section_id]
		if is_instance_valid(provider) or provider is RefCounted:
			var section_data: Variant = provider.call("serialize_save_data")
			if section_data is Dictionary:
				data[section_id] = section_data
	return data


func _restore_extensions(data: Dictionary) -> void:
	for section_id: String in _sections:
		var provider: Variant = _sections[section_id]
		if not (is_instance_valid(provider) or provider is RefCounted):
			continue
		provider.call("deserialize_save_data", data.get(section_id, {}))


func _migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var version: int = int(data.get("version", 1))
	if version > VERSION:
		push_error("SaveManager: save version %d is newer than supported version %d." % [version, VERSION])
		return {}
	while version < VERSION:
		match version:
			1:
				data["extensions"] = data.get("extensions", {})
				version = 2
				data["version"] = version
			2:
				var player_data: Dictionary = data.get("player", {})
				player_data["equipment_items"] = player_data.get("equipment_items", [])
				data["player"] = player_data
				version = 3
				data["version"] = version
			_:
				push_error("SaveManager: no migration from version %d." % version)
				return {}
	return data


func _restore_player(p: SaveData.PlayerData) -> void:
	var player := _get_player()
	if not player:
		return
	var equipment := player.get_node_or_null("EquipmentManager") as EquipmentManager
	if equipment:
		equipment.clear_all()

	player.global_position = p.position

	if player.health_component:
		player.health_component.max_hp = p.max_hp
		player.health_component.hp = clampi(p.hp, 1, p.max_hp)
		player.health_component.is_dead = false
		player.health_changed.emit(player.health_component.hp, player.health_component.max_hp)
	if player.mana_component:
		player.mana_component.max_mp = p.max_mp
		player.mana_component.mp = clampi(p.mp, 0, p.max_mp)
		player.mp_changed.emit(player.mana_component.mp, player.mana_component.max_mp)

	var sc := player.stats_component
	if sc:
		sc.level = p.level
		sc.experience = p.experience
		sc.exp_to_next = p.exp_to_next
		sc.attribute_points = p.attribute_points
		sc.strength = p.strength
		sc.intelligence = p.intelligence
		sc.agility = p.agility
		sc.endurance = p.endurance
		sc._recalculate_all()
		player._apply_stats()
		sc.stat_changed.emit("strength", sc.strength)

	if player.inventory:
		for i: int in range(player.inventory.capacity):
			player.inventory.set_slot(i, null, 0)
		for entry: Dictionary in p.inventory_items:
			var item := load(entry["path"]) as ItemData
			if item:
				player.inventory.set_slot(entry["slot"], item, entry["quantity"])

	if player._skill_pool:
		var sm := player.skill_manager as SkillManager
		if sm:
			var pool := player._skill_pool
			if not p.skill_left.is_empty():
				sm.equip_hand("left", pool.get_skill(p.skill_left))
			if not p.skill_right.is_empty():
				sm.equip_hand("right", pool.get_skill(p.skill_right))
			for i: int in range(mini(p.skill_slots.size(), 6)):
				var sid: String = p.skill_slots[i]
				if sid.is_empty():
					continue
				var skill := pool.get_skill(sid)
				if skill:
					sm.equip_slot(i, skill)
			if not p.skill_upgrade_state.is_empty():
				sm.restore_skill_state(p.skill_upgrade_state)
			for key: String in p.skill_cooldowns:
				var remaining: float = p.skill_cooldowns[key]
				var inst: SkillInstance = sm._find_instance(key)
				if inst:
					inst.current_cooldown = remaining
					sm._cooldowns[key] = remaining
					sm.cooldown_changed.emit(key, remaining, sm._get_cooldown_total(key))

	if player.mastery_manager:
		player.mastery_manager.restore_state(p.mastery_state)
		player._rebuild_perk_triggers()
	var buff_manager := player.get_node_or_null("BuffManager") as BuffManager
	if buff_manager:
		buff_manager.restore_state(p.buff_state)

	# Equipment is rebuilt after ordinary buffs because restore_state() clears runtime buffs first.
	if equipment:
		for entry: Dictionary in p.equipment_items:
			var item := load(str(entry.get("path", ""))) as EquipmentData
			if item:
				equipment.equip(item)
		if player.health_component:
			player.health_component.hp = clampi(p.hp, 1, player.health_component.max_hp)
			player.health_changed.emit(player.health_component.hp, player.health_component.max_hp)
		if player.mana_component:
			player.mana_component.mp = clampi(p.mp, 0, player.mana_component.max_mp)
			player.mp_changed.emit(player.mana_component.mp, player.mana_component.max_mp)


func _restore_world(w: SaveData.WorldData) -> void:
	var gr := GameRuntime.instance
	if gr and gr.world_runtime:
		gr.world_runtime.state_manager.set_all_states(w.object_states)
		gr.world_runtime.restore_registered_objects()
	if WorldTime.instance:
		WorldTime.instance.hour = w.world_time_hour


func _restore_region(meta: SaveData.MetaData) -> void:
	if meta.region_id.is_empty():
		return
	var gr := GameRuntime.instance
	if not gr or not gr.get_region_runtime():
		return
	await gr.get_region_runtime().ensure_region(meta.region_id)
	if gr.world_runtime:
		gr.world_runtime.restore_registered_objects()


func _restore_quests(q: SaveData.QuestSave) -> void:
	var player := _get_player()
	if not player:
		return
	var qm: QuestManager = player.get("quest_manager")
	if qm:
		qm.set_completed_quests(q.completed)
		qm.restore_active_quests(q.active)


func _path(slot: int) -> String:
	return "user://save_%d.sav" % slot


func _get_player() -> Player:
	var tree := get_tree()
	if not tree:
		return null
	return tree.get_first_node_in_group("player") as Player
