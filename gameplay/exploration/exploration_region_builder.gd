class_name ExplorationRegionBuilder
extends RefCounted
var game: MVPGame

func _init(owner_game: MVPGame) -> void:
	game = owner_game

func _build_camp() -> void:
	_add_interaction("篝火：恢复并保存", Vector2(-150, 50), func(): game._restore_player(); game._save_progress(); game.ui.notify("休整完成，生命和法力已恢复。"))
	_add_interaction("查阅探索日志", Vector2(150, -180), game.ui.show_journal)
	_add_interaction("营地训练：分配属性", Vector2(0, -180), game._show_training)
	_add_interaction("施法工作台：加工材料", Vector2(0, 130), game.workshop.show_crafts, "mechanism")
	_add_interaction("测绘员艾妲：营地委托" if game.progress.claims.has("cartographer_rescued") else "营地委托板", Vector2(200, 35), game._show_quests, "person" if game.progress.claims.has("cartographer_rescued") else "note")
	var dummy := load("res://world/object/wooden_crate.tscn").instantiate() as MapObject
	dummy.persistent_id = "camp.training_crate"
	dummy.position = Vector2(250, 180)
	game.region_root.add_child(dummy)

func _build_props(layout: RefCounted) -> void:
	for i in range(layout.props.size()):
		var spec: Dictionary = layout.props[i]
		if spec.kind == "chest":
			continue # Discoveries and supplies use fixed grants, not equipment drops.
		var position: Vector2 = spec.position
		var blocked := false
		for item in game.current_data.interaction_points():
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
			node.persistent_id = "%s.prop.%d" % [game.region_id, i]
		node.position = position
		game.region_root.add_child(node)

func _spawn_enemy(spec: ExplorationEncounterData, layout: RefCounted, index: int) -> void:
	var boss := bool(spec.boss)
	var enemy := load("res://entities/boss/fire_lord.tscn" if boss else "res://entities/enemy/enemy.tscn").instantiate() as Enemy
	enemy.name = "Encounter_%d" % index
	var point: Vector2 = spec.pos
	if not layout.is_point_clear(point, 28):
		for candidate in layout.enemy_offsets:
			var occupied := false
			for other in game.active_enemies:
				if candidate.distance_to(other.position) < 65:
					occupied = true
			if not occupied:
				point = candidate
				break
	enemy.position = point
	if not boss:
		enemy.enemy_type = 2 if game.region_id == "gate" and index == 0 else 0
		enemy.ai_role = int(spec.role) as Enemy.AIRole
	if boss:
		var data := load("res://content/bosses/fire_lord.tres").duplicate(true) as BossData
		data.resists = {"fire": 0.1 if game.progress.choices.get("waterworks_choice", "") == "cooling" else 0.3}
		enemy.boss_data = data
	game.region_root.add_child(enemy)
	var hp := int(spec.hp)
	if boss and game.progress.choices.get("waterworks_choice", "") == "cooling":
		hp = int(hp * 0.75)
	enemy.max_hp = hp
	enemy.health_component.max_hp = hp
	enemy.health_component.hp = hp
	enemy.detect_range = 440
	enemy.move_speed = float(spec.speed)
	enemy.attack_damage = 9 if not boss else 15
	enemy.died.connect(game._on_enemy_died.bind(enemy, GameRuntime.instance.get_region_session().generation), CONNECT_ONE_SHOT)
	game.active_enemies.append(enemy)

func _add_interaction(title: String, point: Vector2, callback: Callable, kind: String = "note") -> ExplorationInteractable:
	var node := ExplorationInteractable.new()
	node.title = title
	node.kind = kind
	node.position = point
	node.callback = callback
	game.region_root.add_child(node)
	return node

func _add_discovery(entry: ExplorationDiscoveryData) -> void:
	if entry.hide_when_claimed and game.progress.claims.has(entry.id):
		return
	var label := str(entry.title)
	if game.progress.claims.has(entry.id):
		label += "（已记录）"
	var node := _add_interaction(label, entry.pos, Callable(), entry.kind)
	node.callback = game.presenter.inspect_discovery.bind(entry, node)
