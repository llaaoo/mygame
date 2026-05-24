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

## 实体 Tick 注册表 — 所有需要持续 tick 的实体组件在此注册
## 实体实现 tick(delta) 方法，SimulationRuntime 统一驱动
var _entity_tickers: Array[Node] = []

## 暂停标记
var is_paused: bool = false
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
	
	# 订阅 CommandBus 命令
	call_deferred("_subscribe_to_bus")


## 注入外部依赖（由 GameRuntime 在初始化时调用）
func setup_dependencies(spatial_index: WorldSpatialIndex, state_manager: WorldStateManager) -> void:
	_spatial_index = spatial_index
	
	# SurfaceManager 作为外观层
	_surface_manager = SurfaceManager.new()
	_surface_manager.name = "SurfaceManager"
	_surface_manager.setup(_surface_scheduler, spatial_index)
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
	# oiled + fire → burning（传播）
	var oil_fire := SurfaceReaction.new()
	oil_fire.rule_id = "oil_fire"
	oil_fire.required_state = "oiled"
	oil_fire.required_tags = ["fire"]
	oil_fire.result_state = "burning"
	oil_fire.result_duration = 8.0
	oil_fire.spread_to_neighbors = true
	oil_fire.spread_tags = ["fire"]
	oil_fire.spread_damage = 1.0
	_surface_manager.register_reaction(oil_fire)
	
	# wet + ice → frozen
	var wet_ice := SurfaceReaction.new()
	wet_ice.rule_id = "wet_ice"
	wet_ice.required_state = "wet"
	wet_ice.required_tags = ["ice"]
	wet_ice.result_state = "frozen"
	wet_ice.result_duration = 5.0
	wet_ice.entity_status_path = "res://gameplay/abilities/data/frozen.tres"
	_surface_manager.register_reaction(wet_ice)
	
	# wet + fire → dry（灭火）
	var wet_fire := SurfaceReaction.new()
	wet_fire.rule_id = "wet_fire"
	wet_fire.required_state = "wet"
	wet_fire.required_tags = ["fire"]
	wet_fire.result_state = "dry"
	wet_fire.result_duration = 0.0
	_surface_manager.register_reaction(wet_fire)
	
	# burning + ice → dry（灭火）
	var burn_ice := SurfaceReaction.new()
	burn_ice.rule_id = "burn_ice"
	burn_ice.required_state = "burning"
	burn_ice.required_tags = ["ice"]
	burn_ice.result_state = "dry"
	burn_ice.result_duration = 0.0
	_surface_manager.register_reaction(burn_ice)
	
	# burning + water/wet → dry
	var burn_wet := SurfaceReaction.new()
	burn_wet.rule_id = "burn_wet"
	burn_wet.required_state = "burning"
	burn_wet.required_tags = ["water"]
	burn_wet.result_state = "dry"
	burn_wet.result_duration = 0.0
	_surface_manager.register_reaction(burn_wet)
	
	# dry + fire → burning（火焰技能命中干燥地面）
	var dry_fire := SurfaceReaction.new()
	dry_fire.rule_id = "dry_fire"
	dry_fire.required_state = "dry"
	dry_fire.required_tags = ["fire"]
	dry_fire.result_state = "burning"
	dry_fire.result_duration = 5.0
	dry_fire.entity_status_path = "res://gameplay/abilities/data/burning.tres"
	_surface_manager.register_reaction(dry_fire)
	
	# dry + ice → frozen（冰技能命中干燥地面）
	var dry_ice := SurfaceReaction.new()
	dry_ice.rule_id = "dry_ice"
	dry_ice.required_state = "dry"
	dry_ice.required_tags = ["ice"]
	dry_ice.result_state = "frozen"
	dry_ice.result_duration = 4.0
	dry_ice.entity_status_path = "res://gameplay/abilities/data/frozen.tres"
	_surface_manager.register_reaction(dry_ice)


## ── 实体 Tick 注册 ──

## 注册需要每帧 tick 的实体/组件（替代独立 _process）
func register_ticker(node: Node) -> void:
	if node in _entity_tickers:
		return
	_entity_tickers.append(node)


## 注销（实体销毁时调用）
func unregister_ticker(node: Node) -> void:
	_entity_tickers.erase(node)


## 统一 tick（由 GameRuntime._process 驱动）
func tick(delta: float) -> void:
	if is_paused:
		return
	
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
	# 倒序遍历以支持 tick 中安全删除
	for i in range(_entity_tickers.size() - 1, -1, -1):
		var ticker := _entity_tickers[i]
		if not is_instance_valid(ticker):
			_entity_tickers.remove_at(i)
			continue
		if ticker.has_method("tick"):
			ticker.tick(delta)


## 公开访问器（替代外部直接访问 _surface_manager）
func get_surface_manager() -> SurfaceManager:
	return _surface_manager


## ── CommandBus 订阅 ──

func _subscribe_to_bus() -> void:
	var gr := GameRuntime.instance
	if not gr:
		call_deferred("_subscribe_to_bus")
		return
	var bus := gr.get_command_bus()
	if bus:
		bus.subscribe_for_target(RuntimeCommand.TYPE_SURFACE_CHANGE, RuntimeCommand.Target.SIMULATION, _on_surface_change_command)
		bus.subscribe_for_target(RuntimeCommand.TYPE_RESPAWN_REQUEST, RuntimeCommand.Target.SIMULATION, _on_respawn_request_command)


func _on_respawn_request_command(cmd: RuntimeCommand) -> void:
	if not _respawn_scheduler:
		return
	var object_id: String = cmd.payload.get("object_id", "")
	var respawn_time: float = cmd.payload.get("respawn_time", 0.0)
	if respawn_time > 0.0 and not object_id.is_empty():
		_respawn_scheduler.enqueue(object_id, respawn_time)
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
		var cell_radius := ceili(surface_radius / 64.0) + 1
		var center := Vector2i(floori(pos.x / 64), floori(pos.y / 64))
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				var cell := Vector2i(center.x + dx, center.y + dy)
				var dist := pos.distance_to(Vector2(cell.x * 64 + 32, cell.y * 64 + 32))
				if dist <= surface_radius:
					_surface_manager.apply_tags(cell, aoe_tags, "aoe_%s" % display_name)
	
	# AOE 伤害
	if aoe_radius > 0.0 and aoe_damage > 0 and _spatial_index:
		var targets: Array = _spatial_index.query_radius(pos, aoe_radius)
		var hit_count := 0
		for t in targets:
			if t.has_method("take_damage"):
				CombatExecutor.report_hit(null, t, aoe_damage, pos, null, aoe_tags)
				hit_count += 1
		if hit_count > 0:
			print("💥 SimulationRuntime: AOE 伤害 %d → %d 目标 (r=%.0f, tags=%s)" % [aoe_damage, hit_count, aoe_radius, aoe_tags])


func _to_string() -> String:
	return "SimulationRuntime(surf=%d, prop=%d, resp=%d)" % [
		_surface_scheduler._active_surfaces.size() if _surface_scheduler else 0,
		_propagation_scheduler._jobs.size() if _propagation_scheduler else 0,
		_respawn_scheduler._respawn_queue.size() if _respawn_scheduler else 0
	]
