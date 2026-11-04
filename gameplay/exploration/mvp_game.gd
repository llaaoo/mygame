class_name MVPGame
extends Node

const REGIONS := ["camp", "yard", "archive", "powder", "drain", "cistern", "sanctum", "gate", "boss"]
const QUEST_IDS := ["rescue", "waterworks", "research"]
const EXTRA_ACTIONS := ["pulse", "frost_sigil", "focus", "water_call", "oil_flask", "storm_sigil", "echo_mark", "venom_mist"]
const SAVE_SLOT := 2
const SECTION := "exploration_mvp"

var progress := ExplorationProgress.new()
var player: Player
var region_root: Node2D
var region_id := ""
var current_data: ExplorationRegionData
var active_enemies: Array[Enemy] = []
var ui: ExpeditionUI
var _switching := false
var _defeated := false
var _save_dirty := false
var _save_delay := 0.0
var persistence_enabled := true
var ready_for_play := false
var quests: Array[ExplorationQuestData] = []
var workshop: CastingWorkshop
var _generator := RunRoomGenerator.new()
var _renderer := PrisonArena.new()

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	player = $Player
	player.skill_manager.combinations.allow_layered_fields = true
	var preview: Node2D = preload("res://gameplay/abilities/fields/field_placement_preview.gd").new()
	preview.name = "FieldPlacementPreview"
	player.add_child(preview)
	player.add_child(preload("res://gameplay/abilities/fields/preparation_overlay.gd").new())
	for id in EXTRA_ACTIONS:
		player.skill_manager.pool.add_skill(load("res://gameplay/abilities/data/%s_data.tres" % id))
	for recipe in player.skill_manager.combinations.recipes:
		player.skill_manager.pool.add_skill(recipe.result_skill)
	var saves := SaveManager.instance
	saves.active_slot = SAVE_SLOT
	saves.progress_only = true
	saves.register_section(SECTION, progress)
	saves.progress_reload_requested.connect(reload_progress)
	saves.before_save.connect(_sync_progress)
	progress.deserialize_save_data(saves.read_extension(SAVE_SLOT, SECTION))
	player.skill_manager.combinations.supplies.restore(progress.casting_supplies)
	GameRuntime.instance.get_world_runtime().state_manager.set_all_states(progress.world_states)
	ui = ExpeditionUI.new()
	ui.progress = progress
	ui.journal_provider = journal_text
	add_child(ui)
	ui.travel_requested.connect(request_travel)
	ui.replay_requested.connect(replay_encounters)
	workshop = CastingWorkshop.new(self)
	ui.materials_requested.connect(workshop.show_materials)
	for id in QUEST_IDS:
		quests.append(load("res://content/exploration/quests/%s.tres" % id))
	player.died.connect(_on_player_died)
	_apply_knowledge()
	_restore_loadout()
	_restore_character()
	_change_region("camp")
	ready_for_play = true
	player.skill_manager.hand_changed.connect(func(_source: String): _queue_save())
	player.skill_manager.slot_changed.connect(func(_slot: int): _queue_save())
	player.skill_manager.combinations.supplies.changed.connect(_queue_save)
	ui.show_panel("余烬监狱 · 探索与组合", "你回到一座被封锁的监狱。火花、震荡和凝神在火、霜、雷阵中产生不同法术；水引和树脂创造新的环境条件。\n\n普通施法保留适配恩赐并获得增益；按住Shift施法可消耗恩赐，换取更强形态，随后失去持续收益。共鸣护盾也需要Shift＋震荡才主动引爆。\n\n左键近战，右键火花，空格闪避，E交互，J日志，M材料，K编组。先读营地的施法材料手册，再去外院学习火阵。", [{"title": "开始探索 / 继续旅程", "callback": ui.close_modal}])

func get_active_region() -> Node2D:
	return region_root

func _queue_save() -> void:
	_save_dirty = true
	_save_delay = 1.0

func _process(delta: float) -> void:
	if _save_dirty and ready_for_play and not get_tree().paused:
		_save_delay -= delta
		if _save_delay <= 0:
			_save_progress()

func _apply_knowledge() -> void:
	var sm := player.skill_manager
	var previous := sm.known_actions.duplicate()
	sm.known_actions = progress.actions.duplicate()
	sm.combinations.learned_recipes = progress.recipes.duplicate()
	for pair in [["pulse", 0], ["focus", 1], ["frost_sigil", 2], ["water_call", 3], ["fire_sigil", 4], ["ignite", 5]]:
		if progress.actions.has(pair[0]) and (previous.is_empty() or not previous.has(pair[0])):
			var slot: int = pair[1]
			if sm.get_slot(slot) != null:
				slot = -1
				for i in range(SkillManager.MAX_SLOTS):
					if sm.get_slot(i) == null:
						slot = i
						break
			if slot >= 0:
				sm.equip_slot(slot, sm.pool.get_skill(pair[0]))
	if previous.is_empty():
		sm.equip_hand("right", sm.pool.get_skill("ignite"))

func _restore_character() -> void:
	var stats := player.stats_component
	for key in progress.character_state.get("stats", {}):
		if key in ["level", "experience", "exp_to_next", "attribute_points", "strength", "intelligence", "agility", "endurance"]:
			stats.set(key, int(progress.character_state.stats[key]))
	stats._recalculate_all()
	player._apply_stats()
	if player.mastery_manager and progress.character_state.has("mastery"):
		player.mastery_manager.restore_state(progress.character_state.mastery)
	stats.stat_changed.emit("level", stats.level)

func request_travel(destination: String) -> void:
	if _switching or destination not in REGIONS:
		return
	_switching = true
	call_deferred("_change_region", destination)

func _clear_temporary() -> void:
	player.skill_manager.combinations.cancel("区域切换")
	player.skill_manager.combinations.clear_field()
	player._cancel_charge()
	player._cancel_channel()
	player.aiming_sources.clear()
	player.hide_aim()
	if player.summon_manager:
		player.summon_manager.clear_all()
	player.get_node("BuffManager").clear_all()
	var sim := GameRuntime.instance.get_simulation_runtime()
	sim._surface_scheduler._active_surfaces.clear()
	sim._propagation_scheduler._jobs.clear()
	sim._respawn_scheduler._respawn_queue.clear()
	GameRuntime.instance.get_command_bus().dispatch()
	GameRuntime.instance.get_world_runtime().prepare_region_swap()
	if is_instance_valid(region_root):
		remove_child(region_root)
		region_root.queue_free()
	region_root = null
	active_enemies.clear()

func _change_region(destination: String) -> void:
	_clear_temporary()
	region_id = destination
	progress.visited[destination] = true
	current_data = load("res://content/exploration/%s.tres" % destination)
	region_root = Node2D.new()
	region_root.name = "ExplorationRegion"
	add_child(region_root)
	var layout := _generator.generate_room(current_data.seed, 0, current_data.room_type)
	current_data.reserve_interaction_space(layout)
	if destination == "camp":
		layout.obstacles.clear()
	_renderer.build(region_root, layout)
	region_root.add_child(preload("res://gameplay/exploration/surface_overlay.gd").new())
	player.global_position = layout.entry_offset
	if destination == "camp":
		_restore_player()
		_build_camp()
	else:
		_build_props(layout)
		if not progress.cleared.has(destination):
			for i in range(current_data.encounters.size()):
				_spawn_enemy(current_data.encounters[i], layout, i)
	for entry in current_data.discoveries:
		_add_discovery(entry)
	for entry in current_data.events:
		_add_interaction(entry.title, entry.pos, _show_world_event.bind(entry), "mechanism")
	for spec in current_data.spell_objects:
		var object := SpellWorldObject.new()
		object.spec = spec
		object.position = spec.pos
		object.completed = progress.claims.has(spec.id)
		object.solved.connect(_on_spell_object_solved)
		region_root.add_child(object)
	for entry in current_data.exits:
		var target := str(entry.target)
		if destination == "camp" and target == "yard":
			_add_interaction(entry.title, entry.pos, func(): request_travel("yard"), "passage")
		else:
			_add_interaction(entry.title, entry.pos, _use_exit.bind(entry), "passage")
	if destination == "camp" and progress.cleared.has("gate"):
		_add_interaction("捷径：重卫关隘", Vector2(0, 280), func(): request_travel("gate"), "passage")
	if destination == "camp" and progress.choices.has("waterworks_choice"):
		_add_interaction("捷径：蓄水机房", Vector2(-300, 280), func(): request_travel("cistern"), "passage")
	if destination == "cistern" and progress.choices.has("waterworks_choice"):
		var shortcut := _add_interaction("检修梯：返回营地", Vector2(0, 300), func(): request_travel("camp"), "passage")
		shortcut.name = "WaterworksShortcut"
	player.mana_component.mp_regen_rate = 5.0 if progress.choices.get("waterworks_choice", "") == "conduit" else 3.0
	_defeated = false
	player.ui_blocked = false
	_switching = false
	_update_objective()
	_save_progress()

func _build_camp() -> void:
	_add_interaction("篝火：恢复并保存", Vector2(-150, 50), func(): _restore_player(); _save_progress(); ui.notify("休整完成，生命和法力已恢复。"))
	_add_interaction("查阅探索日志", Vector2(150, -180), ui.show_journal)
	_add_interaction("营地训练：分配属性", Vector2(0, -180), _show_training)
	_add_interaction("施法工作台：加工材料", Vector2(0, 130), workshop.show_crafts, "mechanism")
	_add_interaction("测绘员艾妲：营地委托" if progress.claims.has("cartographer_rescued") else "营地委托板", Vector2(200, 35), _show_quests, "person" if progress.claims.has("cartographer_rescued") else "note")
	var dummy := load("res://world/object/wooden_crate.tscn").instantiate() as MapObject
	dummy.persistent_id = "camp.training_crate"
	dummy.position = Vector2(250, 180)
	region_root.add_child(dummy)

func _show_training() -> void:
	var stats := player.stats_component
	var text := "可用属性点：%d\n力量 %d · 智力 %d · 敏捷 %d · 耐力 %d\n\n战斗获得经验，升级获得属性点。力量影响近战，智力影响魔法，敏捷影响移动，耐力影响生命。训练结果自动保存。" % [stats.attribute_points, stats.strength, stats.intelligence, stats.agility, stats.endurance]
	var buttons: Array[Dictionary] = []
	for pair in [["strength", "力量"], ["intelligence", "智力"], ["agility", "敏捷"], ["endurance", "耐力"]]:
		buttons.append({"title": pair[1] + " +1", "disabled": stats.attribute_points <= 0, "callback": _train.bind(pair[0])})
	buttons.append({"title": "完成训练", "callback": ui.close_modal})
	ui.show_panel("营地训练", text, buttons)

func _train(stat: String) -> void:
	if player.stats_component.spend_attribute_point(stat):
		_save_progress()
	_show_training()

func _build_props(layout: RefCounted) -> void:
	for i in range(layout.props.size()):
		var spec: Dictionary = layout.props[i]
		if spec.kind == "chest":
			continue # Discoveries and supplies use fixed grants, not equipment drops.
		var position: Vector2 = spec.position
		var blocked := false
		for item in current_data.discoveries + current_data.exits + current_data.events + current_data.spell_objects:
			if position.distance_to(item.pos) < 80:
				blocked = true
		if blocked:
			continue
		var path := "res://world/object/wooden_crate.tscn"
		if spec.kind == "barrel":
			path = "res://world/object/oil_barrel.tscn"
		elif spec.kind == "trap":
			path = "res://world/traps/spike_trap.tscn"
		var node := load(path).instantiate() as Node2D
		if node is MapObject:
			node.persistent_id = "%s.prop.%d" % [region_id, i]
		node.position = position
		region_root.add_child(node)

func _spawn_enemy(spec: Dictionary, layout: RefCounted, index: int) -> void:
	var boss := bool(spec.get("boss", false))
	var enemy := load("res://entities/boss/fire_lord.tscn" if boss else "res://entities/enemy/enemy.tscn").instantiate() as Enemy
	enemy.name = "Encounter_%d" % index
	var point: Vector2 = spec.pos
	if not layout.is_point_clear(point, 28):
		for candidate in layout.enemy_offsets:
			var occupied := false
			for other in active_enemies:
				if candidate.distance_to(other.position) < 65:
					occupied = true
			if not occupied:
				point = candidate
				break
	enemy.position = point
	if not boss:
		enemy.enemy_type = 2 if region_id == "gate" and index == 0 else 0
		enemy.ai_role = int(spec.get("role", 0)) as Enemy.AIRole
	if boss:
		var data := load("res://content/bosses/fire_lord.tres").duplicate(true) as BossData
		data.resists = {"fire": 0.1 if progress.choices.get("waterworks_choice", "") == "cooling" else 0.3}
		enemy.boss_data = data
	region_root.add_child(enemy)
	var hp := int(spec.hp)
	if boss and progress.choices.get("waterworks_choice", "") == "cooling":
		hp = int(hp * 0.75)
	enemy.max_hp = hp
	enemy.health_component.max_hp = hp
	enemy.health_component.hp = hp
	enemy.detect_range = 440
	enemy.move_speed = float(spec.get("speed", 105))
	enemy.attack_damage = 9 if not boss else 15
	enemy.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)
	active_enemies.append(enemy)

func _add_interaction(title: String, point: Vector2, callback: Callable, kind: String = "note") -> ExplorationInteractable:
	var node := ExplorationInteractable.new()
	node.title = title
	node.kind = kind
	node.position = point
	node.callback = callback
	region_root.add_child(node)
	return node

func _add_discovery(entry: Dictionary) -> void:
	if entry.get("hide_when_claimed", false) and progress.claims.has(entry.id):
		return
	var label := str(entry.title)
	if progress.claims.has(entry.id):
		label += "（已记录）"
	var node := _add_interaction(label, entry.pos, Callable(), entry.get("kind", "note"))
	node.callback = func():
		if entry.get("requires_clear", false) and not active_enemies.is_empty():
			ui.notify("先清除守卫，再靠近这里调查。")
			return
		if progress.claim(entry.id, entry.title, entry.text, entry.get("actions", []), entry.get("recipes", [])):
			player.skill_manager.combinations.supplies.grant(entry.get("materials", {}))
			_apply_knowledge()
			if entry.get("heal", false):
				player.heal(60)
				player.restore_mp(60)
			node.set_title(str(entry.title) + "（已记录）")
			_save_progress()
			_update_objective()
			if entry.id == "cartographer_rescued":
				ui.notify("测绘员已沿清理过的道路返回营地。回去交付委托可领取成长奖励。")
			if entry.get("hide_when_claimed", false):
				node.queue_free()
		ui.show_panel(entry.title, entry.text, [{"title": "记入日志，继续探索", "callback": ui.close_modal}])

func _use_exit(entry: Dictionary) -> void:
	if entry.get("requires_clear", false) and not active_enemies.is_empty():
		ui.notify("通道封锁：先清除本区域守卫。")
		return
	if region_id == "yard" and entry.target == "powder" and not progress.actions.has("fire_sigil"):
		ui.notify("请先阅读入口旁的火阵铭刻记录。")
		return
	if region_id == "boss" and entry.target == "camp" and progress.completed:
		ui.show_panel("监狱封锁已解除", "你击败了火焰领主，完成这次探索。\n\n已掌握的技能、配方、发现记录与捷径已保存。可以返回营地探索遗漏支路，或在暂停菜单重置遭遇再试不同组合。", [{"title": "返回营地", "callback": func(): ui.close_modal(); request_travel("camp")}])
		return
	request_travel(entry.target)

func _on_enemy_died(enemy: Enemy) -> void:
	active_enemies.erase(enemy)
	if active_enemies.is_empty():
		progress.cleared[region_id] = true
		if region_id == "boss":
			progress.completed = true
		ui.notify("区域已清理，前方通路开启。" if region_id != "boss" else "火焰领主已倒下。前往出口完成探索！")
		call_deferred("_save_progress")
	_update_objective()

func _update_objective() -> void:
	ui.heading.text = current_data.title + (" · 已清理" if progress.cleared.has(region_id) else "")
	ui.objective.text = current_data.description + ("\n剩余敌人：%d" % active_enemies.size() if not active_enemies.is_empty() else "")
	if region_id == "boss" and progress.choices.get("waterworks_choice", "") == "cooling":
		ui.objective.text += "\n冷却水路生效：领主生命 -25%，火抗降至10%。"

func _restore_player() -> void:
	player.health_component.is_dead = false
	player.health_component.invincible = false
	player.health_component.hp = player.health_component.max_hp
	player.mana_component.mp = player.mana_component.max_mp
	player.health_changed.emit(player.health_component.hp, player.health_component.max_hp)
	player.mp_changed.emit(player.mana_component.mp, player.mana_component.max_mp)
	player.collision_shape.set_deferred("disabled", false)
	player.set_process(true)
	player.set_physics_process(true)
	player.state_machine.transition_to("idle")
	player.mana_component.mp_regen_rate = 3.0
	player.health_component.regen_rate = 0.6
	player.skill_manager.combinations.reset_session()

func _on_player_died() -> void:
	if _defeated:
		return
	_defeated = true
	progress.deaths += 1
	player.skill_manager.combinations.cancel("死亡")
	player.skill_manager.combinations.clear_field()
	_save_progress()
	ui.show_panel("远征中断", "返回营地重新整备。已学知识、已清理区域和发现记录保留；未清理遭遇重新开始。", [{"title": "返回营地", "callback": func(): ui.close_modal(); request_travel("camp")}], true)

func _save_progress() -> void:
	if not persistence_enabled:
		return
	_save_dirty = false
	if not SaveManager.instance.save_game(SAVE_SLOT):
		ui.notify("保存失败：本次进度仍在内存，请检查可写空间后按F5重试。")

func _sync_progress() -> void:
	progress.casting_supplies = player.skill_manager.combinations.supplies.serialize()
	progress.world_states = GameRuntime.instance.get_world_runtime().state_manager.get_all_states().duplicate(true)
	progress.loadout = player.skill_manager.serialize_skill_state()
	progress.loadout["__configured"] = {}
	var stats: Dictionary = {}
	for key in ["level", "experience", "exp_to_next", "attribute_points", "strength", "intelligence", "agility", "endurance"]:
		stats[key] = player.stats_component.get(key)
	progress.character_state = {"stats": stats, "mastery": player.mastery_manager.serialize_state() if player.mastery_manager else {}}

func reload_progress() -> void:
	ui.close_modal()
	_clear_temporary()
	progress.deserialize_save_data(SaveManager.instance.read_extension(SAVE_SLOT, SECTION))
	player.skill_manager.combinations.supplies.restore(progress.casting_supplies)
	GameRuntime.instance.get_world_runtime().state_manager.set_all_states(progress.world_states)
	_apply_knowledge()
	_restore_loadout()
	_restore_character()
	request_travel("camp")

func _restore_loadout() -> void:
	if progress.loadout.is_empty():
		return
	var sm := player.skill_manager
	sm.unequip_hand("left")
	sm.unequip_hand("right")
	for i in range(SkillManager.MAX_SLOTS):
		sm.unequip_slot(i)
	sm.restore_skill_state(progress.loadout)

func replay_encounters() -> void:
	progress.cleared.clear()
	progress.completed = false
	progress.world_states.clear()
	GameRuntime.instance.get_world_runtime().state_manager.set_all_states({})
	request_travel("camp")

func _show_quests() -> void:
	var text := "艾妲：把你发现的知识和监狱的变化带回来。奖励每项只发放一次，重置遭遇不会重复领取。\n\n" if progress.claims.has("cartographer_rescued") else "委托留在营地，随时可以查看和交付。奖励每项只发放一次。\n\n"
	var buttons: Array[Dictionary] = []
	for quest in quests:
		var claimed := progress.claims.has("quest." + quest.id)
		var complete := quest.is_complete(progress)
		var status := "已交付" if claimed else ("可交付" if complete else "进行中")
		text += "%s [%s] %d/%d\n%s\n奖励：%d 属性点\n\n" % [quest.title, status, quest.objective_count(progress), quest.required_claims.size() + quest.required_clears.size(), quest.description, quest.attribute_points]
		buttons.append({"title": ("已交付：" if claimed else "交付：") + quest.title, "disabled": claimed or not complete, "callback": _claim_quest.bind(quest)})
	buttons.append({"title": "继续探索", "callback": ui.close_modal})
	ui.show_panel("营地委托", text, buttons)

func _claim_quest(quest: ExplorationQuestData) -> void:
	if region_id != "camp" or quest not in quests or not quest.is_complete(progress):
		return
	if progress.claim("quest." + quest.id, "委托完成：" + quest.title, "营地收到你的报告，获得 %d 属性点。" % quest.attribute_points, [], []):
		player.stats_component.attribute_points += quest.attribute_points
		_save_progress()
	_show_quests()

func _show_world_event(entry: Dictionary) -> void:
	if not active_enemies.is_empty():
		ui.notify("机房守卫仍在巡逻，先清场再操作阀门。")
		return
	var selected: String = progress.choices.get(entry.id, "")
	var text: String = entry.text + "\n\n"
	var buttons: Array[Dictionary] = []
	for choice in entry.choices:
		text += choice.title + ("（当前）" if selected == choice.id else "") + "\n" + choice.text + "\n\n"
		buttons.append({"title": choice.title, "disabled": selected == choice.id, "callback": _choose_world_event.bind(entry, choice)})
	text += "只能维持一条水路；可以回来改道。效果从下一次进入区域生效，不会重新生成已清场的敌人。"
	buttons.append({"title": "稍后决定", "callback": ui.close_modal})
	ui.show_panel(entry.title, text, buttons)

func _choose_world_event(entry: Dictionary, choice: Dictionary) -> void:
	if entry not in current_data.events or choice not in entry.choices or not active_enemies.is_empty():
		return
	progress.choices[entry.id] = choice.id
	var record: String = choice.title + "：" + choice.text
	if not progress.claim(entry.id, entry.title, record, [], []):
		for note in progress.journal:
			if note.id == entry.id:
				note.text = record
	_save_progress()
	ui.close_modal()
	ui.notify("水路已改道，通往营地的检修梯已开启。")
	if not region_root.has_node("WaterworksShortcut"):
		var shortcut := _add_interaction("检修梯：返回营地", Vector2(0, 300), func(): request_travel("camp"), "passage")
		shortcut.name = "WaterworksShortcut"

func journal_text() -> String:
	var text := "行动提示\n左键近战；右键/6火花；1震荡、2凝神、3霜阵、4水引、5火阵需探索学习。雷阵与泼洒树脂用K编组；M配置材料，营地工作台加工。J关闭日志。\n\n法术联动\n水引→冰霜：凝冻，额外30%伤害；冰霜→火球：融化，额外60%；水引→火球：蒸发，额外30%；水引→雷矢/雷环：导电，额外45%；雷息→雷矢/雷环：额外35%。目标反应使用命中时的状态，地面反应另行改变水、冰、蒸汽和带电区域。\n\n路线与清理进度\n营地 → 外院 → 火药库 → 重卫关隘 → 熔炉大厅\n外院 → 军械档案 → 静默祈堂\n火药库 → 排水回廊 → 蓄水机房\n"
	for id in REGIONS:
		var data := load("res://content/exploration/%s.tres" % id) as ExplorationRegionData
		var state := "已清理" if progress.cleared.has(id) else ("已探索" if progress.visited.has(id) else "未探索")
		text += "%s · %s\n" % [data.title, state]
	text += "\n实验线索\n不同类型的法阵可以共同保留，站在重叠处观察同一动作的变化；同类重建只更新自己的阵。资源费用会在预览中合计。\n余烬战意赋予近战火焰性质，可对敌人和物体使用同一套火焰反应。\n雷电沿连通水面传播，干燥空隙会截断它；观察地面，也注意自己的站位。\n"
	text += "\n恩赐的保留与消耗\n普通施法保留恩赐：余烬/霜行使适配火焰/冰霜法术伤害+20%；雷息保留原有雷击命中+35%。按住Shift施放适配动作可消耗恩赐，额外3 MP：余烬换取更高伤害与燃烧区，霜行换取穿透/范围，雷息换取散射/范围。释放后失去其攻击、移速等持续收益。\n共鸣护盾在普通震荡时保留，Shift＋震荡才消耗护盾爆破。回响印记仍是一次性准备，正常转化即消费。悬停技能槽查看本次保留/消耗的状态。\n"
	text += "\n营地委托（回营地交付）\n"
	for quest in quests:
		text += "%s · %s · %d/%d\n%s\n" % [quest.title, "已交付" if progress.claims.has("quest." + quest.id) else ("可交付" if quest.is_complete(progress) else "进行中"), quest.objective_count(progress), quest.required_claims.size() + quest.required_clears.size(), quest.description]
	text += "\n已学组合\n"
	for recipe in player.skill_manager.combinations.recipes:
		if progress.recipes.has(recipe.id):
			var action := player.skill_manager.pool.get_skill(recipe.trigger_action_id)
			var condition_cost := " + 1次法阵触发" if not recipe.required_field_type.is_empty() else (" + 消耗准备状态" if recipe.consume_caster_status else "")
			text += "%s + %s → %s · %d MP%s\n%s\n" % [recipe.condition_label(), action.display_name, recipe.result_skill.display_name, recipe.mana_cost, condition_cost, recipe.result_skill.description]
	text += "\n当前水路\n"
	match str(progress.choices.get("waterworks_choice", "")):
		"cooling": text += "冷却熔炉：新遭遇的领主生命 -25%，火抗降至10%。\n"
		"conduit": text += "魔力导流：进入区域后法力回复由3提高到5 MP/秒。\n"
		_: text += "尚未重启。深入排水回廊的蓄水机房调查。\n"
	text += "\n发现记录\n"
	for note in progress.journal:
		text += "\n%s\n%s\n" % [note.title, note.text]
	return text

func _on_spell_object_solved(spec: Dictionary) -> void:
	if progress.claim(spec.id, spec.title, spec.hint + "\n机关已解开，材料收入行囊。", [], []):
		player.skill_manager.combinations.supplies.grant(spec.get("materials", {}))
		ui.notify("解开：" + str(spec.title) + " · 材料已收入行囊，按M查看。")
		call_deferred("_save_progress")
