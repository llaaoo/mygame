class_name RunManager
extends Node

const NORMAL_ROOM_COUNT := 4
const REWARD_CHOICES := 3
const ARENA_CENTER := Vector2(6000, 6000)
const ARENA_SIZE := Vector2(1120, 720)
const WALL_THICKNESS := 36.0

const ENEMY_SCENE := preload("res://entities/enemy/enemy.tscn")
const BOSS_SCENE := preload("res://entities/boss/fire_lord.tscn")
const OIL_BARREL_SCENE := preload("res://world/object/oil_barrel.tscn")
const CRATE_SCENE := preload("res://world/object/wooden_crate.tscn")
const CHEST_SCENE := preload("res://world/loot/chest.tscn")
const SPIKE_TRAP_SCENE := preload("res://world/traps/spike_trap.tscn")
const RUN_META_SCRIPT := preload("res://gameplay/run/run_meta.gd")

const SKILL_REWARDS: Array[Dictionary] = [
	{"id": "skill_lightning", "title": "闪电箭", "description": "将闪电箭装入一个快捷槽。", "type": "skill", "skill_id": "lightning_bolt"},
	{"id": "skill_poison", "title": "毒云", "description": "将毒云装入一个快捷槽。", "type": "skill", "skill_id": "poison_cloud"},
	{"id": "skill_summon", "title": "召唤骷髅", "description": "将召唤骷髅装入一个快捷槽。", "type": "skill", "skill_id": "summon_skeleton"},
	{"id": "skill_charge", "title": "蓄力火球", "description": "将蓄力火球装入一个快捷槽。", "type": "skill", "skill_id": "charged_fireball"},
]

const STAT_REWARDS: Array[Dictionary] = [
	{"id": "heal", "title": "喘息", "description": "恢复 40 点生命值。", "type": "heal", "amount": 40},
	{"id": "max_hp", "title": "硬化皮肤", "description": "最大生命值 +20，并立刻恢复 20 点。", "type": "max_hp", "amount": 20},
	{"id": "mana", "title": "法力储备", "description": "最大法力值 +20，并立刻恢复 20 点。", "type": "mana", "amount": 20},
	{"id": "damage", "title": "锐化武器", "description": "近战伤害 +5。", "type": "damage", "amount": 5},
]

const RELIC_REWARDS: Array[Dictionary] = [
	{"id": "relic_firebrand", "title": "余烬指环", "description": "火焰技能伤害 +25%。", "type": "relic", "relic_id": "firebrand"},
	{"id": "relic_stormcoil", "title": "风暴线圈", "description": "闪电技能伤害 +25%。", "type": "relic", "relic_id": "stormcoil"},
	{"id": "relic_iron_heart", "title": "铁心护符", "description": "最大生命 +30，并恢复生命。", "type": "relic", "relic_id": "iron_heart"},
]

var state := RunState.new()
var meta = RUN_META_SCRIPT.new()
var persist_meta: bool = true
var _rng := RandomNumberGenerator.new()
var _player: Player = null
var _scene_root: Node = null
var _room_root: Node2D = null
var _alive_enemies: Array[Node] = []
var _overlay_layer: CanvasLayer = null
var _reward_panel: Control = null
var _pause_panel: Control = null
var _status_label: Label = null
var _objective_label: Label = null
var _meta_label: Label = null
var _progress_labels: Array[Label] = []
var _exit_area: Area2D = null
var _exit_label: Label = null
var _exit_visual: Polygon2D = null
var _room_origin := ARENA_CENTER


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	meta.load_from_disk()
	if SaveManager.instance:
		SaveManager.instance.register_section("roguelite_meta", meta)
	call_deferred("_bootstrap")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if state.status not in [RunState.Status.RUNNING, RunState.Status.BOSS]:
		return
	_toggle_pause()
	get_viewport().set_input_as_handled()


func _bootstrap() -> void:
	await get_tree().process_frame
	_scene_root = get_tree().current_scene
	_player = get_tree().get_first_node_in_group("player") as Player
	if not _scene_root or not _player:
		push_warning("[RunManager] Player or scene root missing; roguelite loop disabled.")
		return

	if not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)

	_create_overlay()
	_start_run()


func _start_run() -> void:
	get_tree().paused = false
	_clear_pause_panel()
	_rng.seed = Time.get_ticks_msec()
	state.start(_rng.seed)
	_room_origin = ARENA_CENTER
	_player.global_position = _room_origin
	_player.ui_blocked = false
	_apply_meta_starting_bonus()
	_remove_existing_encounter_actors()
	_update_meta_display()
	_spawn_normal_room()


func _remove_existing_encounter_actors() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if node != _player and is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(node):
			node.queue_free()
	_alive_enemies.clear()


func _spawn_normal_room() -> void:
	state.status = RunState.Status.RUNNING
	_clear_reward_panel()
	if _player:
		_player.ui_blocked = false
		_player.global_position = _room_origin + Vector2(-360, 0)

	var room_type := _normal_room_type(state.room_index)
	_rebuild_room(room_type)
	_spawn_room_props(room_type)
	_spawn_room_exit(false)

	var is_elite_room := room_type == "elite"
	var count := 2 if is_elite_room else 3 + state.room_index
	var radius := 230.0 + float(state.room_index) * 35.0
	for i in range(count):
		var enemy := ENEMY_SCENE.instantiate() as Enemy
		enemy.name = "RunEnemy_%d_%d" % [state.room_index + 1, i + 1]
		enemy.enemy_type = 2 if is_elite_room else mini((i + state.room_index) % 3, 2)
		if state.room_index >= 1 and i == count - 1:
			enemy.enemy_type = 2
		if is_elite_room:
			enemy.max_hp = 90 + i * 20
			enemy.attack_damage = 18 + i * 3
			enemy.move_speed = 145.0
		_room_root.add_child(enemy)
		var angle := TAU * float(i) / float(count)
		enemy.global_position = _room_origin + Vector2(cos(angle), sin(angle)) * radius
		_track_enemy(enemy)

	_show_status("精英房" if is_elite_room else "房间 %d/%d" % [state.room_index + 1, NORMAL_ROOM_COUNT])
	_show_objective("清除全部敌人，打开出口。")
	_update_progress()


func _spawn_boss_room() -> void:
	state.status = RunState.Status.BOSS
	_clear_reward_panel()
	if _player:
		_player.ui_blocked = false
		_player.global_position = _room_origin + Vector2(-360, 0)

	_rebuild_room("boss")
	_spawn_room_props("boss")
	_spawn_room_exit(false)

	var boss := BOSS_SCENE.instantiate() as Boss
	boss.name = "RunBoss_FireLord"
	if not boss.boss_data:
		boss.boss_data = load("res://content/bosses/fire_lord.tres") as BossData
	_room_root.add_child(boss)
	boss.global_position = _room_origin + Vector2(300, 0)
	boss.add_to_group("boss")
	_track_enemy(boss)
	_show_status("Boss 房")
	_show_objective("击败火焰领主。")
	_update_progress()


func _normal_room_type(index: int) -> String:
	match index:
		0:
			return "barracks"
		1:
			return "traps"
		2:
			return "explosive"
		_:
			return "elite"


func _rebuild_room(room_type: String) -> void:
	if _room_root and is_instance_valid(_room_root):
		_unregister_room_map_objects(_room_root)
		_room_root.queue_free()

	_room_root = Node2D.new()
	_room_root.name = "RunArena_%s_%d" % [room_type, state.room_index + 1]
	_scene_root.add_child(_room_root)

	_build_floor(room_type)
	_build_walls()
	_build_room_title(room_type)


func _unregister_room_map_objects(root: Node) -> void:
	var gr := GameRuntime.instance
	if not gr or not gr.get_world_runtime():
		return
	for child in root.get_children():
		if child is MapObject:
			gr.get_world_runtime().unregister_object(child)
		_unregister_room_map_objects(child)


func _build_floor(room_type: String) -> void:
	var base_color := Color(0.10, 0.11, 0.13, 1.0)
	var accent := Color(0.25, 0.29, 0.33, 1.0)
	match room_type:
		"barracks":
			base_color = Color(0.12, 0.12, 0.15, 1.0)
			accent = Color(0.29, 0.25, 0.20, 1.0)
		"traps":
			base_color = Color(0.08, 0.10, 0.10, 1.0)
			accent = Color(0.18, 0.34, 0.32, 1.0)
		"explosive":
			base_color = Color(0.13, 0.10, 0.08, 1.0)
			accent = Color(0.36, 0.20, 0.12, 1.0)
		"elite":
			base_color = Color(0.11, 0.075, 0.13, 1.0)
			accent = Color(0.48, 0.22, 0.48, 1.0)
		"boss":
			base_color = Color(0.12, 0.07, 0.06, 1.0)
			accent = Color(0.48, 0.15, 0.08, 1.0)

	var floor := _rect_poly(_room_origin, ARENA_SIZE, base_color)
	floor.name = "Floor"
	floor.z_index = -120
	_room_root.add_child(floor)

	for x in range(-4, 5):
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(accent.r, accent.g, accent.b, 0.35)
		line.z_index = -115
		var px := _room_origin.x + float(x) * 128.0
		line.points = PackedVector2Array([
			Vector2(px, _room_origin.y - ARENA_SIZE.y * 0.5),
			Vector2(px, _room_origin.y + ARENA_SIZE.y * 0.5),
		])
		_room_root.add_child(line)

	for y in range(-2, 3):
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(accent.r, accent.g, accent.b, 0.35)
		line.z_index = -115
		var py := _room_origin.y + float(y) * 128.0
		line.points = PackedVector2Array([
			Vector2(_room_origin.x - ARENA_SIZE.x * 0.5, py),
			Vector2(_room_origin.x + ARENA_SIZE.x * 0.5, py),
		])
		_room_root.add_child(line)


func _build_walls() -> void:
	var half := ARENA_SIZE * 0.5
	_add_wall("NorthWall", _room_origin + Vector2(0, -half.y - WALL_THICKNESS * 0.5), Vector2(ARENA_SIZE.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall("SouthWall", _room_origin + Vector2(0, half.y + WALL_THICKNESS * 0.5), Vector2(ARENA_SIZE.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall("WestWall", _room_origin + Vector2(-half.x - WALL_THICKNESS * 0.5, 0), Vector2(WALL_THICKNESS, ARENA_SIZE.y))
	_add_wall("EastWall", _room_origin + Vector2(half.x + WALL_THICKNESS * 0.5, 0), Vector2(WALL_THICKNESS, ARENA_SIZE.y))


func _add_wall(name_str: String, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = name_str
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	_room_root.add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	var visual := _rect_poly(Vector2.ZERO, size, Color(0.05, 0.055, 0.065, 1.0))
	visual.z_index = -80
	body.add_child(visual)


func _build_room_title(room_type: String) -> void:
	var label := Label.new()
	label.name = "RoomTitle"
	label.position = _room_origin + Vector2(-520, -330)
	label.text = _room_name(room_type)
	label.add_theme_font_size_override("font_size", 26)
	label.modulate = Color(0.95, 0.82, 0.52, 0.9)
	_room_root.add_child(label)


func _room_name(room_type: String) -> String:
	match room_type:
		"barracks":
			return "牢房营区"
		"traps":
			return "机关走廊"
		"explosive":
			return "油桶库房"
		"elite":
			return "重卫刑场"
		"boss":
			return "熔火审判厅"
	return "未知房间"


func _spawn_room_props(room_type: String) -> void:
	match room_type:
		"barracks":
			_spawn_crate(Vector2(-80, -180))
			_spawn_crate(Vector2(110, 170))
			_spawn_chest(Vector2(430, -230))
		"traps":
			_spawn_trap(Vector2(-40, -90))
			_spawn_trap(Vector2(170, 110))
			_spawn_crate(Vector2(-250, 180))
			_spawn_chest(Vector2(410, 220))
		"explosive":
			_spawn_barrel(Vector2(-20, -120))
			_spawn_barrel(Vector2(150, 60))
			_spawn_barrel(Vector2(310, -170))
			_spawn_crate(Vector2(-250, -180))
			_spawn_chest(Vector2(420, 230))
		"elite":
			_spawn_barrel(Vector2(-130, 0))
			_spawn_trap(Vector2(70, -190))
			_spawn_trap(Vector2(70, 190))
			_spawn_chest(Vector2(410, 0))
		"boss":
			_spawn_barrel(Vector2(-60, -210))
			_spawn_barrel(Vector2(80, 210))
			_spawn_trap(Vector2(230, -210))
			_spawn_trap(Vector2(230, 210))


func _spawn_barrel(offset: Vector2) -> void:
	var node := OIL_BARREL_SCENE.instantiate() as Node2D
	_room_root.add_child(node)
	node.global_position = _room_origin + offset


func _spawn_crate(offset: Vector2) -> void:
	var node := CRATE_SCENE.instantiate() as Node2D
	_room_root.add_child(node)
	node.global_position = _room_origin + offset


func _spawn_chest(offset: Vector2) -> void:
	var node := CHEST_SCENE.instantiate() as Node2D
	_room_root.add_child(node)
	node.global_position = _room_origin + offset


func _spawn_trap(offset: Vector2) -> void:
	var node := SPIKE_TRAP_SCENE.instantiate() as Node2D
	_room_root.add_child(node)
	node.global_position = _room_origin + offset


func _spawn_room_exit(unlocked: bool) -> void:
	_exit_area = Area2D.new()
	_exit_area.name = "RunExit"
	_exit_area.global_position = _room_origin + Vector2(500, 0)
	_exit_area.monitoring = true
	_exit_area.collision_layer = 2048
	_exit_area.collision_mask = 2
	_exit_area.body_entered.connect(_on_exit_body_entered)
	_room_root.add_child(_exit_area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(92, 160)
	shape.shape = rect
	_exit_area.add_child(shape)

	_exit_visual = _rect_poly(Vector2.ZERO, Vector2(92, 160), Color(0.16, 0.18, 0.20, 0.78))
	_exit_visual.z_index = -20
	_exit_area.add_child(_exit_visual)

	_exit_label = Label.new()
	_exit_label.position = Vector2(-44, -92)
	_exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_label.custom_minimum_size = Vector2(88, 32)
	_exit_area.add_child(_exit_label)

	_set_exit_unlocked(unlocked)


func _set_exit_unlocked(unlocked: bool) -> void:
	if not _exit_area:
		return
	_exit_area.set_meta("unlocked", unlocked)
	if _exit_visual:
		_exit_visual.color = Color(0.18, 0.85, 0.42, 0.85) if unlocked else Color(0.18, 0.20, 0.23, 0.82)
	if _exit_label:
		_exit_label.text = "出口" if unlocked else "封锁"
		_exit_label.modulate = Color(0.55, 1.0, 0.65, 1.0) if unlocked else Color(0.8, 0.8, 0.8, 0.7)


func _on_exit_body_entered(body: Node2D) -> void:
	if body != _player:
		return
	if not _exit_area or not bool(_exit_area.get_meta("unlocked", false)):
		return
	if state.status == RunState.Status.RUNNING:
		_enter_reward_state()
	elif state.status == RunState.Status.BOSS:
		_complete_run()


func _track_enemy(enemy: Node) -> void:
	if not enemy:
		return
	_alive_enemies.append(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)


func _on_enemy_died(enemy: Node) -> void:
	_alive_enemies.erase(enemy)
	call_deferred("_check_room_clear")


func _check_room_clear() -> void:
	_alive_enemies = _alive_enemies.filter(func(node: Node) -> bool:
		return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()
	)
	_update_progress()
	if not _alive_enemies.is_empty():
		return

	match state.status:
		RunState.Status.RUNNING:
			_on_normal_room_cleared()
		RunState.Status.BOSS:
			_on_boss_room_cleared()


func _on_normal_room_cleared() -> void:
	_set_exit_unlocked(true)
	_show_objective("出口已开启。进入出口选择奖励。")


func _on_boss_room_cleared() -> void:
	_set_exit_unlocked(true)
	_show_objective("Boss 已击败。进入出口完成本次探索。")


func _enter_reward_state() -> void:
	state.status = RunState.Status.REWARD
	_show_status("房间清理完成")
	_show_objective("选择一个奖励。")
	if _player:
		_player.ui_blocked = true
	state.active_reward_choices = _roll_rewards()
	_show_reward_panel(state.active_reward_choices)


func _roll_rewards() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for skill_reward in SKILL_REWARDS:
		if not state.rewards_taken.has(str(skill_reward.get("id", ""))):
			pool.append(skill_reward)
	pool.append_array(STAT_REWARDS)
	for relic in RELIC_REWARDS:
		if not state.relic_ids.has(str(relic.get("relic_id", ""))):
			pool.append(relic)
	if _normal_room_type(state.room_index) == "elite":
		for relic in RELIC_REWARDS:
			if not state.relic_ids.has(str(relic.get("relic_id", ""))):
				pool.append(relic)
	var choices: Array[Dictionary] = []
	var chosen_ids: Array[String] = []
	while choices.size() < REWARD_CHOICES and not pool.is_empty():
		var idx := _rng.randi_range(0, pool.size() - 1)
		var reward: Dictionary = pool.pop_at(idx)
		var reward_id := str(reward.get("id", ""))
		if chosen_ids.has(reward_id):
			continue
		choices.append(reward)
		chosen_ids.append(reward_id)
	return choices


func _show_reward_panel(choices: Array[Dictionary]) -> void:
	_clear_reward_panel()

	var dim := ColorRect.new()
	dim.name = "RewardDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.48)

	var panel := PanelContainer.new()
	panel.name = "RunRewardPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 320)
	panel.position = Vector2(-380, -160)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.06, 0.075, 0.96), Color(0.82, 0.64, 0.32, 0.75), 2))
	dim.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var title := Label.new()
	title.text = "选择奖励"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.95, 0.82, 0.52, 1.0)
	root.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)

	for reward in choices:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(230, 190)
		btn.text = "%s\n\n%s" % [reward.get("title", "奖励"), reward.get("description", "")]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_reward_selected.bind(reward))
		row.add_child(btn)

	_reward_panel = dim
	_overlay_layer.add_child(dim)


func _on_reward_selected(reward: Dictionary) -> void:
	if state.status != RunState.Status.REWARD:
		return
	state.record_reward(reward.get("id", ""))
	_apply_reward(reward)
	state.advance_room()
	if state.room_index >= NORMAL_ROOM_COUNT:
		_spawn_boss_room()
	else:
		_spawn_normal_room()


func _apply_reward(reward: Dictionary) -> void:
	if not _player:
		return
	match reward.get("type", ""):
		"skill":
			_apply_skill_reward(str(reward.get("skill_id", "")))
		"heal":
			_player.heal(int(reward.get("amount", 0)))
		"max_hp":
			var health := _player.health_component
			var amount := int(reward.get("amount", 0))
			health.max_hp += amount
			_player.heal(amount)
			_player.health_changed.emit(health.hp, health.max_hp)
		"mana":
			var mana := _player.mana_component
			if mana:
				var amount := int(reward.get("amount", 0))
				mana.max_mp += amount
				_player.restore_mp(amount)
				_player.mp_changed.emit(mana.mp, mana.max_mp)
		"damage":
			if _player.combat_component:
				_player.combat_component.attack_damage += int(reward.get("amount", 0))
		"relic":
			_apply_relic(str(reward.get("relic_id", "")))
	_update_meta_display()


func _apply_relic(relic_id: String) -> void:
	if relic_id.is_empty() or state.relic_ids.has(relic_id):
		return
	state.record_relic(relic_id)
	match relic_id:
		"firebrand":
			_add_tag_multiplier(["fire"], 1.25)
		"stormcoil":
			_add_tag_multiplier(["lightning"], 1.25)
		"iron_heart":
			var health := _player.health_component
			health.max_hp += 30
			_player.heal(30)


func _add_tag_multiplier(tags: Array[String], multiplier: float) -> void:
	if not _player or not _player.skill_manager or not _player.skill_manager.executor:
		return
	var modifier := TagMultiplierModifier.new()
	modifier.required_tags = tags
	modifier.multiplier = multiplier
	_player.skill_manager.executor.add_modifier(modifier)


func _apply_meta_starting_bonus() -> void:
	if not _player:
		return
	var health_bonus: int = meta.starting_health_bonus()
	if health_bonus > 0:
		_player.health_component.max_hp += health_bonus
		_player.heal(health_bonus)
	var mana_bonus: int = meta.starting_mana_bonus()
	if mana_bonus > 0 and _player.mana_component:
		_player.mana_component.max_mp += mana_bonus
		_player.restore_mp(mana_bonus)


func _apply_skill_reward(skill_id: String) -> void:
	if skill_id.is_empty() or not _player.skill_manager:
		return
	var skill := load("res://gameplay/abilities/data/%s_data.tres" % skill_id) as SkillData
	if not skill:
		return
	_configure_reward_skill(skill_id, skill)
	var pool := _player.skill_manager.pool
	if not pool:
		pool = SkillPool.new()
		_player.skill_manager.pool = pool
	pool.add_skill(skill)
	pool.build()

	var slot := _first_reward_slot()
	_player.skill_manager.equip_slot(slot, skill)


func _configure_reward_skill(skill_id: String, skill: SkillData) -> void:
	match skill_id:
		"lightning_bolt":
			skill.archetype = "linear_projectile"
			skill.visual = load("res://content/visuals/lightning_visual.tres")
			skill.tags = ["lightning"]
		"poison_cloud":
			skill.archetype = "persistent_aoe"
			skill.aoe_visual = load("res://content/visuals/poison_aoe_visual.tres")
			skill.tags = ["poison"]
		"summon_skeleton":
			skill.archetype = "summon_entity"
			skill.summon_data = load("res://content/summons/skeleton_warrior.tres") as SummonData
			skill.tags = ["summon", "shadow"]
		"charged_fireball":
			skill.archetype = "linear_projectile"
			skill.visual = load("res://content/visuals/fire_visual.tres")
			skill.cast_type = "charge"
			skill.tags = ["fire", "charge"]


func _first_reward_slot() -> int:
	if not _player or not _player.skill_manager:
		return 0
	for i in range(4):
		if _player.skill_manager.get_slot(i) == null:
			return i
	return state.completed_rooms % 4


func _complete_run() -> void:
	state.status = RunState.Status.CLEARED
	var cinders: int = _finish_meta_run(true)
	_update_meta_display()
	if _player:
		_player.ui_blocked = true
	_show_status("Run 通关")
	_show_objective("你击败了火焰领主。")
	_show_result_panel("通关", "你完成了这次地牢探索。\n获得 %d 余烬。" % cinders, "重新开始")


func _on_player_died() -> void:
	if state.status == RunState.Status.CLEARED or state.status == RunState.Status.FAILED:
		return
	state.status = RunState.Status.FAILED
	var cinders: int = _finish_meta_run(false)
	_update_meta_display()
	_show_status("Run 失败")
	_show_result_panel("失败", "本次探索结束。\n带回 %d 余烬。" % cinders, "重新开始")


func _show_result_panel(title_text: String, body_text: String, button_text: String) -> void:
	_clear_reward_panel()
	var dim := ColorRect.new()
	dim.name = "RunResultDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.56)

	var panel := PanelContainer.new()
	panel.name = "RunResultPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 360)
	panel.position = Vector2(-250, -180)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.06, 0.075, 0.96), Color(0.82, 0.64, 0.32, 0.75), 2))
	dim.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color(0.95, 0.82, 0.52, 1.0)
	box.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 16)
	box.add_child(body)

	var upgrades := HBoxContainer.new()
	upgrades.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrades.add_theme_constant_override("separation", 10)
	box.add_child(upgrades)

	var vitality := Button.new()
	vitality.custom_minimum_size = Vector2(190, 54)
	upgrades.add_child(vitality)

	var focus := Button.new()
	focus.custom_minimum_size = Vector2(190, 54)
	upgrades.add_child(focus)

	var refresh_upgrades := func() -> void:
		vitality.text = "生命强化 %d/%d\n%d 余烬" % [meta.vitality_rank, RUN_META_SCRIPT.MAX_UPGRADE_RANK, meta.upgrade_cost("vitality")]
		focus.text = "法力强化 %d/%d\n%d 余烬" % [meta.focus_rank, RUN_META_SCRIPT.MAX_UPGRADE_RANK, meta.upgrade_cost("focus")]
		vitality.disabled = not meta.can_upgrade("vitality")
		focus.disabled = not meta.can_upgrade("focus")
	refresh_upgrades.call()

	vitality.pressed.connect(func() -> void:
		if meta.purchase_upgrade("vitality"):
			body.text = "%s\n生命强化将在下一局生效。" % body_text
			refresh_upgrades.call()
			_update_meta_display()
	)
	focus.pressed.connect(func() -> void:
		if meta.purchase_upgrade("focus"):
			body.text = "%s\n法力强化将在下一局生效。" % body_text
			refresh_upgrades.call()
			_update_meta_display()
	)

	var restart := Button.new()
	restart.text = button_text
	restart.custom_minimum_size = Vector2(0, 44)
	restart.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://main.tscn")
	)
	box.add_child(restart)

	_reward_panel = dim
	_overlay_layer.add_child(dim)


func _toggle_pause() -> void:
	if _pause_panel and is_instance_valid(_pause_panel):
		get_tree().paused = false
		_clear_pause_panel()
		return
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.name = "RunPauseDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.52)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := PanelContainer.new()
	panel.name = "RunPausePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 230)
	panel.position = Vector2(-180, -115)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.06, 0.075, 0.98), Color(0.48, 0.62, 0.74, 0.72), 2))
	dim.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.92, 0.94, 0.97, 1.0)
	box.add_child(title)

	var resume := Button.new()
	resume.text = "继续"
	resume.custom_minimum_size = Vector2(0, 42)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)

	var abandon := Button.new()
	abandon.text = "放弃本局"
	abandon.custom_minimum_size = Vector2(0, 42)
	abandon.pressed.connect(_abandon_run)
	box.add_child(abandon)

	_pause_panel = dim
	_overlay_layer.add_child(dim)


func _abandon_run() -> void:
	if state.status not in [RunState.Status.RUNNING, RunState.Status.BOSS]:
		return
	get_tree().paused = false
	_clear_pause_panel()
	state.status = RunState.Status.FAILED
	var cinders: int = _finish_meta_run(false)
	_update_meta_display()
	_show_status("Run 放弃")
	_show_result_panel("本局结束", "你带回了 %d 余烬。" % cinders, "重新开始")


func _create_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "RunOverlay"
	_overlay_layer.layer = 140
	add_child(_overlay_layer)

	var top := PanelContainer.new()
	top.name = "RunTopPanel"
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -310
	top.offset_right = 310
	top.offset_top = 16
	top.offset_bottom = 96
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.045, 0.055, 0.86), Color(0.50, 0.45, 0.34, 0.5), 1))
	_overlay_layer.add_child(top)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	top.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.modulate = Color(0.95, 0.82, 0.52, 1.0)
	header.add_child(_status_label)

	for i in range(NORMAL_ROOM_COUNT + 1):
		var pip := Label.new()
		pip.text = "●"
		pip.add_theme_font_size_override("font_size", 16)
		header.add_child(pip)
		_progress_labels.append(pip)

	_objective_label = Label.new()
	_objective_label.add_theme_font_size_override("font_size", 13)
	_objective_label.modulate = Color(0.86, 0.88, 0.90, 0.95)
	box.add_child(_objective_label)

	_meta_label = Label.new()
	_meta_label.add_theme_font_size_override("font_size", 12)
	_meta_label.modulate = Color(0.62, 0.72, 0.78, 0.95)
	box.add_child(_meta_label)
	_update_meta_display()


func _show_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


func _show_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = text


func _update_progress() -> void:
	for i in range(_progress_labels.size()):
		var label := _progress_labels[i]
		if i < state.room_index:
			label.modulate = Color(0.35, 0.95, 0.55, 1.0)
		elif i == state.room_index:
			label.modulate = Color(0.95, 0.82, 0.52, 1.0)
		else:
			label.modulate = Color(0.55, 0.57, 0.60, 0.7)


func _update_meta_display() -> void:
	if not _meta_label:
		return
	var relics := "无"
	if not state.relic_ids.is_empty():
		relics = ", ".join(state.relic_ids)
	_meta_label.text = "余烬 %d | 通关 %d | 遗物 %s | 常驻 HP %d MP %d" % [meta.cinders, meta.clears, relics, meta.vitality_rank, meta.focus_rank]


func _finish_meta_run(cleared: bool) -> int:
	if not persist_meta:
		return state.completed_rooms * 2 + (10 if cleared else 0)
	return meta.finish_run(state.completed_rooms, cleared)


func _clear_reward_panel() -> void:
	if _reward_panel and is_instance_valid(_reward_panel):
		_reward_panel.queue_free()
	_reward_panel = null


func _clear_pause_panel() -> void:
	if _pause_panel and is_instance_valid(_pause_panel):
		_pause_panel.queue_free()
	_pause_panel = null


func _rect_poly(center: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var half := size * 0.5
	poly.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])
	poly.color = color
	return poly


func _panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
