class_name SaveManager
extends Node
## SaveManager — F5 保存 / F9 读取
## 格式: 二进制 Variant (FileAccess.store_var/get_var)


const VERSION: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_F5:
		save_game(1)
	elif event.keycode == KEY_F9:
		load_game(1)


## ── 保存 ──

func save_game(slot: int) -> void:
	var root := SaveData.Root.new()
	root.meta = _collect_meta()
	root.player = _collect_player()
	root.world = _collect_world()
	root.quest = _collect_quests()

	var data: Dictionary = root.serialize()
	var path: String = _path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: 无法写入 %s" % path)
		return
	file.store_var(data, true)
	file.close()
	print("💾 已保存到 %s" % path)


## ── 读取 ──

func load_game(slot: int) -> void:
	var path: String = _path(slot)
	if not FileAccess.file_exists(path):
		print("💾 存档不存在: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var data: Variant = file.get_var(true)
	file.close()
	if data == null or not (data is Dictionary):
		push_error("SaveManager: 存档数据损坏")
		return

	var version: int = (data as Dictionary).get("version", 0)
	if version != VERSION:
		print("💾 存档版本 %d ≠ 当前 %d，跳过" % [version, VERSION])
		return

	# 清理瞬态状态
	_cleanup_transient()

	var root := SaveData.Root.deserialize(data as Dictionary)
	_restore_player(root.player)
	_restore_world(root.world)
	_restore_quests(root.quest)
	print("💾 已从 %s 读取" % path)


## ── 清理瞬态 ──

func _cleanup_transient() -> void:
	# 清除所有飞行中的投射物
	for proj in get_tree().get_nodes_in_group("projectile"):
		if is_instance_valid(proj):
			proj.queue_free()
	# 清除死亡画面
	var player := _get_player()
	if player:
		player.set_process(true)
		player.set_physics_process(true)
		if player.health_component:
			player.health_component.is_dead = false
	# 关闭死亡 UI
	var hud := get_tree().get_first_node_in_group("hud") if false else null
	# 清除 CombatExecutor 残留状态
	if CombatExecutor.instance:
		CombatExecutor.instance.enter_phase(CombatPhase.Phase.IDLE)
		CombatExecutor.instance.reset_chain()


## ── 收集 ──

func _collect_meta() -> SaveData.MetaData:
	var m := SaveData.MetaData.new()
	m.timestamp = Time.get_unix_time_from_system()
	var player := _get_player()
	if player and player.stats_component:
		m.player_level = player.stats_component.level
	return m


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

	var sc := player.stats_component
	if sc:
		p.level = sc.level; p.experience = sc.experience
		p.exp_to_next = sc.exp_to_next; p.attribute_points = sc.attribute_points
		p.strength = sc.strength; p.intelligence = sc.intelligence
		p.agility = sc.agility; p.endurance = sc.endurance

	if player.inventory:
		for i: int in range(player.inventory.capacity):
			var slot: Dictionary = player.inventory.get_slot(i)
			if slot.item:
				p.inventory_items.append({"path": slot.item.resource_path, "quantity": slot.quantity, "slot": i})

	var sm := player.skill_manager as SkillManager
	if sm:
		if sm.left_hand and sm.left_hand.data:
			p.skill_left = sm.left_hand.data.get_id()
		if sm.right_hand and sm.right_hand.data:
			p.skill_right = sm.right_hand.data.get_id()
		p.skill_slots.resize(4)
		for i: int in range(4):
			var inst: SkillInstance = sm.get_slot(i)
			p.skill_slots[i] = inst.data.get_id() if inst and inst.data else ""
		p.skill_cooldowns = sm._cooldowns.duplicate()

	return p


func _collect_world() -> SaveData.WorldData:
	var w := SaveData.WorldData.new()
	var gr := GameRuntime.instance
	if gr and gr.world_runtime:
		w.object_states = gr.world_runtime.state_manager.get_all_states()
	if WorldTime.instance:
		w.world_time_hour = WorldTime.instance.hour
	return w


func _collect_quests() -> SaveData.QuestSave:
	var q := SaveData.QuestSave.new()
	var player := _get_player()
	if not player:
		return q
	var qm: QuestManager = player.get("quest_manager")
	if qm:
		q.completed = qm.get_completed_quests()
	return q


## ── 恢复 ──

func _restore_player(p: SaveData.PlayerData) -> void:
	var player := _get_player()
	if not player:
		return

	player.global_position = p.position

	if player.health_component:
		player.health_component.hp = clampi(p.hp, 1, p.max_hp)
		player.health_component.max_hp = p.max_hp
		player.health_component.is_dead = false
		player.health_changed.emit(player.health_component.hp, player.health_component.max_hp)
	if player.mana_component:
		player.mana_component.mp = clampi(p.mp, 0, p.max_mp)
		player.mana_component.max_mp = p.max_mp
		player.mp_changed.emit(player.mana_component.mp, player.mana_component.max_mp)

	var sc := player.stats_component
	if sc:
		sc.level = p.level; sc.experience = p.experience
		sc.exp_to_next = p.exp_to_next; sc.attribute_points = p.attribute_points
		sc.strength = p.strength; sc.intelligence = p.intelligence
		sc.agility = p.agility; sc.endurance = p.endurance
		sc._recalculate_all()
		player._apply_stats()
		# 触发 HUD 刷新（不发 leveled_up——加载时不应弹窗）
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
			for i: int in range(mini(p.skill_slots.size(), 4)):
				var sid: String = p.skill_slots[i]
				if not sid.is_empty():
					var skill := pool.get_skill(sid)
					if skill:
						sm.equip_slot(i, skill)
			# 恢复冷却（同步 _cooldowns 字典 + SkillInstance.current_cooldown）
			sm._cooldowns = p.skill_cooldowns.duplicate()
			for key in sm._cooldowns:
				var remaining: float = sm._cooldowns[key]
				var inst: SkillInstance = sm._find_instance(key)
				if inst:
					inst.current_cooldown = remaining
				sm.cooldown_changed.emit(key, remaining, sm._get_cooldown_total(key))


func _restore_world(w: SaveData.WorldData) -> void:
	var gr := GameRuntime.instance
	if gr and gr.world_runtime:
		gr.world_runtime.state_manager.set_all_states(w.object_states)
	if WorldTime.instance:
		WorldTime.instance.hour = w.world_time_hour


func _restore_quests(q: SaveData.QuestSave) -> void:
	var player := _get_player()
	if not player:
		return
	var qm: QuestManager = player.get("quest_manager")
	if qm:
		qm.set_completed_quests(q.completed)


## ── 辅助 ──

func _path(slot: int) -> String:
	return "user://save_%d.sav" % slot


func _get_player() -> Player:
	var tree := get_tree()
	if not tree:
		return null
	return tree.get_first_node_in_group("player") as Player
