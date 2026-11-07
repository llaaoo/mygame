class_name SimulationRuntime
extends Node
## SimulationRuntime — 统一调度所有持续世界行为
##
## 禁止每个系统独立 _process()
## 调度顺序显式、可审计、可暂停

## 子调度器
var _surface_scheduler: SurfaceScheduler = null
var _surface_manager: SurfaceManager = null
var _propagation_scheduler: PropagationScheduler = null
var _respawn_scheduler: RespawnScheduler = null
var _spatial_index: WorldSpatialIndex = null
var _command_bus: CommandBus

## 实体 Tick 注册表 — 所有需要持续 tick 的实体组件在此注册
## 实体实现 tick(delta) 方法，SimulationRuntime 统一驱动
var _entity_tickers: Dictionary = {}

## 暂停标记
var is_paused: bool = false
var elapsed_time := 0.0
var _tick_accumulator: float = 0.0  ## 实体-表面交互低频 tick


func _ready() -> void:
	_surface_scheduler = SurfaceScheduler.new()
	_surface_scheduler.name = "SurfaceScheduler"
	add_child(_surface_scheduler)

	_propagation_scheduler = PropagationScheduler.new()
	_propagation_scheduler.name = "PropagationScheduler"
	add_child(_propagation_scheduler)

	_respawn_scheduler = RespawnScheduler.new()
	_respawn_scheduler.name = "RespawnScheduler"
	add_child(_respawn_scheduler)


func _exit_tree() -> void:
	if not is_instance_valid(_command_bus):
		return
	_command_bus.unsubscribe(RuntimeCommand.TYPE_SURFACE_CHANGE, _on_surface_change_command)
	_command_bus.unsubscribe(RuntimeCommand.TYPE_RESPAWN_REQUEST, _on_respawn_request_command)
	_command_bus = null


## 注入外部依赖（由 GameRuntime 在初始化时调用）
func setup_dependencies(spatial_index: WorldSpatialIndex, state_manager: WorldStateManager, bus: CommandBus) -> void:
	_spatial_index = spatial_index
	_command_bus = bus
	bus.subscribe_for_target(RuntimeCommand.TYPE_SURFACE_CHANGE, RuntimeCommand.Target.SIMULATION, _on_surface_change_command)
	bus.subscribe_for_target(RuntimeCommand.TYPE_RESPAWN_REQUEST, RuntimeCommand.Target.SIMULATION, _on_respawn_request_command)

	# SurfaceManager 作为外观层
	_surface_manager = SurfaceManager.new()
	_surface_manager.name = "SurfaceManager"
	_surface_manager.setup(_surface_scheduler, spatial_index, _propagation_scheduler)
	add_child(_surface_manager)

	# 注册默认 ReactionRule
	_register_default_reactions()

	# 注入 SurfaceManager 到空间索引（使 query_surface() 可用）
	if spatial_index and spatial_index.has_method("set_surface_manager"):
		spatial_index.set_surface_manager(_surface_manager)

	# 传递依赖给子调度器
	if _propagation_scheduler:
		_propagation_scheduler.setup(_surface_scheduler, spatial_index, _surface_manager)
	if _respawn_scheduler:
		_respawn_scheduler.setup(state_manager)


## 注册默认表面反应规则
func _register_default_reactions() -> void:
	for reaction in SurfaceCatalog.all_reactions():
		_surface_manager.register_reaction(reaction)


## ── 实体 Tick 注册 ──

## 注册需要每帧 tick 的实体/组件（替代独立 _process）
func register_ticker(node: Node) -> void:
	var id := node.get_instance_id()
	if _entity_tickers.has(id):
		return
	_entity_tickers[id] = weakref(node)
	node.tree_exiting.connect(_unregister_id.bind(id), CONNECT_ONE_SHOT)

func unregister_ticker(node: Node) -> void:
	if is_instance_valid(node):
		_unregister_id(node.get_instance_id())

func _unregister_id(id: int) -> void:
	_entity_tickers.erase(id)

func clear_region() -> void:
	_surface_scheduler.clear()
	_propagation_scheduler.clear()
	_respawn_scheduler.clear()
	_tick_accumulator = 0.0


## 统一 tick（由 GameRuntime._process 驱动）
func tick(delta: float) -> void:
	if is_paused:
		return

	elapsed_time += delta
	# 调度顺序: Surface → Propagation → Respawn → Entity Tickers
	_surface_scheduler.tick(delta)
	_propagation_scheduler.tick(delta)
	_respawn_scheduler.tick(delta)

	# 实体 Tick（统一驱动，替代各系统独立 _process）
	_tick_entities(delta)

	# 实体-表面交互（低频, 0.5s）
	_tick_accumulator += delta
	if _tick_accumulator >= 0.5 and _surface_manager:
		_tick_accumulator -= 0.5
		_surface_manager.tick_entity_surface()


## 驱动所有注册的实体 ticker
func _tick_entities(delta: float) -> void:
	for id in _entity_tickers.keys():
		var ticker := (_entity_tickers.get(id) as WeakRef).get_ref() as Node if _entity_tickers.has(id) else null
		if not is_instance_valid(ticker) or not ticker.is_inside_tree():
			_entity_tickers.erase(id)
			continue
		if ticker.has_method("tick"):
			ticker.tick(delta)


## 公开访问器（替代外部直接访问 _surface_manager）
func get_surface_manager() -> SurfaceManager:
	return _surface_manager


## ── CommandBus 订阅 ──

func _on_respawn_request_command(cmd: RuntimeCommand) -> void:
	if not _respawn_scheduler:
		return
	var object_id: String = cmd.payload.get("object_id", "")
	var object_path: String = cmd.payload.get("object_path", "")
	var respawn_time: float = cmd.payload.get("respawn_time", 0.0)
	if respawn_time > 0.0 and not object_id.is_empty():
		_respawn_scheduler.enqueue(object_id, respawn_time, object_path)
		print("⏱️ SimulationRuntime: 加入重生队列 %s (%.0fs)" % [object_id, respawn_time])


func _on_surface_change_command(cmd: RuntimeCommand) -> void:
	if not _surface_manager:
		return

	var pos: Vector2 = cmd.payload.get("position", Vector2.ZERO)
	var aoe_radius: float = cmd.payload.get("destruction_radius", 0.0)
	var aoe_damage: int = cmd.payload.get("destruction_aoe_damage", 0)
	var aoe_tags: Array = cmd.payload.get("destruction_aoe_tags", [])
	var surface_state: String = cmd.payload.get("surface_state", "")
	var surface_radius: float = cmd.payload.get("surface_radius", 0.0)
	var display_name: String = cmd.payload.get("display_name", "?")

	# 表面生成
	if not surface_state.is_empty() and surface_radius > 0.0:
		var cell_radius := ceili(surface_radius / 64.0) + 1
		var center := Vector2i(floori(pos.x / 64), floori(pos.y / 64))
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				var cell := Vector2i(center.x + dx, center.y + dy)
				var dist := pos.distance_to(Vector2(cell.x * 64 + 32, cell.y * 64 + 32))
				if dist <= surface_radius:
					_surface_manager.force_set_surface(cell, surface_state, 10.0, "destroyed_%s" % display_name)

		print("💥 SimulationRuntime: 生成 %s 表面 (r=%.0f, pos=%s)" % [surface_state, surface_radius, pos])

	# AOE 标签触发 ReactionRule（如 oiled + fire → burning）
	if not aoe_tags.is_empty() and surface_radius > 0.0:
		# 转换为 Array[String]（JSON 反序列化产生无类型 Array）
		var typed_tags: Array[String] = []
		for t in aoe_tags:
			typed_tags.append(str(t))

		var cell_radius := ceili(surface_radius / 64.0) + 1
		var center := Vector2i(floori(pos.x / 64), floori(pos.y / 64))
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				var cell := Vector2i(center.x + dx, center.y + dy)
				var dist := pos.distance_to(Vector2(cell.x * 64 + 32, cell.y * 64 + 32))
				if dist <= surface_radius:
					_surface_manager.apply_tags(cell, typed_tags, "aoe_%s" % display_name)

	# AOE 伤害
	if aoe_radius > 0.0 and aoe_damage > 0:
		var targets: Array = _collect_aoe_damage_targets(pos, aoe_radius)
		var hit_count := 0
		for t in targets:
			if t.has_method("take_damage"):
				CombatExecutor.report_hit(null, t, aoe_damage, pos, null, aoe_tags)
				hit_count += 1
		if hit_count > 0:
			print("💥 SimulationRuntime: AOE 伤害 %d → %d 目标 (r=%.0f, tags=%s)" % [aoe_damage, hit_count, aoe_radius, aoe_tags])


func _collect_aoe_damage_targets(pos: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var seen: Dictionary = {}
	if _spatial_index:
		for target in _spatial_index.query_radius(pos, radius):
			_add_aoe_target(result, seen, target, pos, radius)
	var tree := get_tree()
	if tree:
		for group_name in ["player", "enemy", "summon"]:
			for node in tree.get_nodes_in_group(group_name):
				_add_aoe_target(result, seen, node, pos, radius)
	return result


func _add_aoe_target(result: Array[Node2D], seen: Dictionary, node: Node, pos: Vector2, radius: float) -> void:
	if not (node is Node2D):
		return
	var target := node as Node2D
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var id := target.get_instance_id()
	if seen.has(id):
		return
	if target.global_position.distance_to(pos) > radius:
		return
	seen[id] = true
	result.append(target)


func _to_string() -> String:
	return "SimulationRuntime(surf=%d, prop=%d, resp=%d)" % [
		_surface_scheduler.active_count() if _surface_scheduler else 0,
		_propagation_scheduler.pending_count() if _propagation_scheduler else 0,
		_respawn_scheduler.pending_count() if _respawn_scheduler else 0
	]

func surface_cells() -> Array:
	return _surface_scheduler.active_cells()

func surface_at(cell: Vector2i) -> Dictionary:
	return _surface_scheduler.get_surface(cell)

func entity_ticker_count() -> int:
	return _entity_tickers.size()
