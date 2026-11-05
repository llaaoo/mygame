class_name SurfaceManager
extends Node
## SurfaceManager — 表面系统统一入口
## 职责：持有 ReactionRule 表，包装 SurfaceScheduler，桥接 Status 系统
##
## 与 WORLD_CONTRACTS.md CONTRACT 2 对齐：Surface 只声明状态，不产生伤害

## 全局引用（供 AoE 等系统查找）
static var instance: SurfaceManager = null
signal reaction_occurred(rule_id: String, cell: Vector2i, source: String)

## 依赖注入
var _surface_scheduler: SurfaceScheduler = null
var _spatial_index: WorldSpatialIndex = null
var _propagation_scheduler: PropagationScheduler = null

## ReactionRule 表（按 required_state 索引，加速查找）
var _reactions: Dictionary = {}  ## String(state) → Array[SurfaceReaction]


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(scheduler: SurfaceScheduler, spatial: WorldSpatialIndex, propagation: PropagationScheduler = null) -> void:
	_surface_scheduler = scheduler
	_spatial_index = spatial
	_propagation_scheduler = propagation


## 注册 ReactionRule
func register_reaction(rule: SurfaceReaction) -> void:
	if not _reactions.has(rule.required_state):
		_reactions[rule.required_state] = []
	_reactions[rule.required_state].append(rule)


## 核心：对指定 cell 应用标签，触发反应
## 返回：是否发生了状态变化
func apply_tags(cell: Vector2i, tags: Array[String], source: String = "") -> bool:
	return _apply_tags(cell, tags, source, {})


func _apply_tags(cell: Vector2i, tags: Array[String], source: String, conducted: Dictionary) -> bool:
	if not _surface_scheduler:
		return false

	var surf := _surface_scheduler.get_surface(cell)
	var current_state: String = surf.get("state", "dry")

	var rules: Array = _reactions.get(current_state, [])
	for rule in rules:
		if not rule is SurfaceReaction:
			continue
		if rule.matches(current_state, tags):
			_apply_reaction(cell, rule, tags, source, conducted)
			return true

	return false


## 执行单个反应
func _apply_reaction(cell: Vector2i, rule: SurfaceReaction, tags: Array[String], source: String, conducted: Dictionary) -> void:
	# 更新表面状态
	_surface_scheduler.set_surface(cell, rule.result_state, rule.result_duration, source)
	if rule.required_state == "wet" and rule.result_state == "electrified":
		_conduct_connected_water(cell, rule.result_duration, source, conducted)
	if rule.spread_to_neighbors and _propagation_scheduler:
		for neighbor in _neighbor_cells(cell):
			_propagation_scheduler.enqueue(cell, neighbor, rule.spread_damage, 1, rule.spread_tags)

	print("🧪 Surface: %s + %s → %s (%.1fs) [%s]" % [rule.required_state, tags, rule.result_state, rule.result_duration, source])

	reaction_occurred.emit(rule.rule_id, cell, source)
	if _spatial_index:
		for entity in _spatial_index.query_cell(cell):
			if entity is Node2D and cell_at(entity.global_position) == cell:
				apply_surface_to(entity)


func _neighbor_cells(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]

func _conduct_connected_water(origin: Vector2i, duration: float, source: String, visited: Dictionary) -> void:
	# One bounded world reaction; damage remains in the existing status tick path.
	if visited.has(origin) or visited.size() >= 48:
		return
	var queue: Array[Vector2i] = [origin]
	visited[origin] = true
	while not queue.is_empty() and visited.size() < 48:
		var current: Vector2i = queue.pop_front()
		for neighbor in _neighbor_cells(current):
			if visited.has(neighbor) or visited.size() >= 48:
				continue
			if get_surface(neighbor).get("state", "dry") != "wet":
				continue
			visited[neighbor] = true
			force_set_surface(neighbor, "electrified", duration, source)
			queue.append(neighbor)


## 获取 cell 上实体应受的 Buff 路径列表（供 InteractionSystem tick 使用）
func get_entity_buffs(cell: Vector2i) -> Array[String]:
	var definition := SurfaceCatalog.definition(str(get_surface(cell).get("state", "dry")))
	return definition.status_paths.duplicate() if definition else [] as Array[String]

static func cell_at(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / 64), floori(position.y / 64))

func surface_at(position: Vector2) -> Dictionary:
	return get_surface(cell_at(position))

func danger_at(position: Vector2, actor: Node = null) -> float:
	var definition := SurfaceCatalog.definition(str(surface_at(position).get("state", "dry")))
	if not definition: return 0.0
	if is_instance_valid(actor) and not definition.danger_status.is_empty() and not ElementCatalog.can_affect(actor, definition.danger_status):
		return 0.0
	return definition.danger

## One position query and one exposure per entity, including multi-group actors.
func tick_entity_surface() -> void:
	if not _surface_scheduler or not get_tree(): return
	var seen: Dictionary = {}
	for group in ["player", "enemy", "summon"]:
		for entity in get_tree().get_nodes_in_group(group):
			if entity is Node2D and not seen.has(entity.get_instance_id()):
				seen[entity.get_instance_id()] = true
				apply_surface_to(entity)
	if _spatial_index:
		for cell: Vector2i in _surface_scheduler.active_cells():
			for entity in _spatial_index.query_cell(cell):
				if entity is Node2D and not seen.has(entity.get_instance_id()) and cell_at(entity.global_position) == cell:
					seen[entity.get_instance_id()] = true
					apply_surface_to(entity)

func apply_surface_to(entity: Node2D) -> void:
	var definition := SurfaceCatalog.definition(str(surface_at(entity.global_position).get("state", "dry")))
	if not definition: return
	var bm := entity.get_node_or_null("BuffManager") as BuffManager
	if bm:
		for status in definition.cleanse_statuses:
			bm.remove_status(status)
		for path in definition.status_paths:
			var buff := load(path) as Buff
			if buff and (not bm.has_buff(buff.status_id) or buff.status_id in definition.refresh_statuses):
				bm.apply_buff(buff)
	elif definition.id == "burning" and entity.has_method("take_damage") and not entity.is_in_group("fire_immune"):
		CombatExecutor.report_hit(null, entity, 3, entity.global_position, null, ["fire", "environment", "dot"])


func get_surface(cell: Vector2i) -> Dictionary:
	if _surface_scheduler:
		return _surface_scheduler.get_surface(cell)
	return {"state": "dry", "remaining": 0.0}


func get_cells_in_radius(pos: Vector2, radius: float) -> Array[Vector2i]:
	if _surface_scheduler:
		return _surface_scheduler.get_cells_in_radius(pos, radius)
	return []


func force_set_surface(cell: Vector2i, state: String, duration: float, source: String = "") -> void:
	if _surface_scheduler:
		_surface_scheduler.set_surface(cell, state, duration, source)

func apply_area(position: Vector2, radius: float, tags: Array[String], source: String, created_state: String = "", duration: float = 8.0, affect_dry: bool = false, payload_tags: Array[String] = []) -> void:
	var center := Vector2i(floori(position.x / 64), floori(position.y / 64))
	var extent := ceili(radius / 64.0) + 1
	var covered: Array[Vector2i] = []
	var conducted: Dictionary = {}
	for x in range(-extent, extent + 1):
		for y in range(-extent, extent + 1):
			var cell := center + Vector2i(x, y)
			# The effect origin always overlaps its containing cell, even for a small spark.
			if cell != center and position.distance_to(Vector2(cell.x * 64 + 32, cell.y * 64 + 32)) > radius:
				continue
			covered.append(cell)
			var current: String = get_surface(cell).get("state", "dry")
			if not created_state.is_empty():
				force_set_surface(cell, "burning" if created_state == "oiled" and current == "burning" else created_state, duration, source)
			elif affect_dry or current != "dry":
				_apply_tags(cell, tags, source, conducted)
	# Paint the entire medium before reacting, so a later cell cannot overwrite propagation.
	for tag in payload_tags:
		for cell in covered:
			_apply_tags(cell, [tag], source, conducted)


func _to_string() -> String:
	return "SurfaceManager(rules=%d, cells=%d)" % [
		_reactions.size(),
		_surface_scheduler._active_surfaces.size() if _surface_scheduler else 0
	]

func reactions_for(state: String) -> Array:
	return _reactions.get(state, []).duplicate()

## Preview and execution read the same rules; this query never mutates the world.
func project_state(initial_state: String, payload_tags: Array[String]) -> String:
	var state := initial_state
	for tag in payload_tags:
		for rule: SurfaceReaction in _reactions.get(state, []):
			if rule.matches(state, [tag]):
				state = rule.result_state
				break
	return state

func describe_surface_path(initial_state: String, payload_tags: Array[String]) -> String:
	var state := initial_state
	var path: Array[String] = [surface_title(state)]
	for tag in payload_tags:
		var next := project_state(state, [tag])
		if next != state:
			path.append(surface_title(next))
		state = next
	return "→".join(path)

static func surface_title(state: String) -> String:
	var definition := SurfaceCatalog.definition(state)
	return definition.title if definition else state

## A prepared cast binds to one actual cell; previews never mutate it.
func revision(cell: Vector2i) -> int:
	return _surface_scheduler.revision(cell) if _surface_scheduler else -1

func consume_prepared_surface(cell: Vector2i, state: String, version: int) -> Dictionary:
	if not _surface_scheduler or version < 0 or revision(cell) != version:
		return {}
	var medium := get_surface(cell)
	if medium.state != state or float(medium.remaining) <= 0:
		return {}
	return _surface_scheduler.take_surface(cell)

func restore_prepared_surface(cell: Vector2i, snapshot: Dictionary) -> void:
	force_set_surface(cell, snapshot.state, snapshot.remaining, snapshot.get("source", ""))
