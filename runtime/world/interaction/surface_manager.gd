class_name SurfaceManager
extends Node
## SurfaceManager — 表面系统统一入口
## 职责：持有 ReactionRule 表，包装 SurfaceScheduler，桥接 Status 系统
##
## 与 WORLD_CONTRACTS.md CONTRACT 2 对齐：Surface 只声明状态，不产生伤害

## 全局引用（供 AoE 等系统查找）
static var instance: SurfaceManager = null

## 依赖注入
var _surface_scheduler: SurfaceScheduler = null
var _spatial_index: WorldSpatialIndex = null

## ReactionRule 表（按 required_state 索引，加速查找）
var _reactions: Dictionary = {}  ## String(state) → Array[SurfaceReaction]


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(scheduler: SurfaceScheduler, spatial: WorldSpatialIndex) -> void:
	_surface_scheduler = scheduler
	_spatial_index = spatial


## 注册 ReactionRule
func register_reaction(rule: SurfaceReaction) -> void:
	if not _reactions.has(rule.required_state):
		_reactions[rule.required_state] = []
	_reactions[rule.required_state].append(rule)


## 核心：对指定 cell 应用标签，触发反应
## 返回：是否发生了状态变化
func apply_tags(cell: Vector2i, tags: Array[String], source: String = "") -> bool:
	if not _surface_scheduler:
		return false
	
	var surf := _surface_scheduler.get_surface(cell)
	var current_state: String = surf.get("state", "dry")
	
	var rules: Array = _reactions.get(current_state, [])
	for rule in rules:
		if not rule is SurfaceReaction:
			continue
		if rule.matches(current_state, tags):
			_apply_reaction(cell, rule, tags, source)
			return true
	
	return false


## 执行单个反应
func _apply_reaction(cell: Vector2i, rule: SurfaceReaction, tags: Array[String], source: String) -> void:
	# 更新表面状态
	_surface_scheduler.set_surface(cell, rule.result_state, rule.result_duration, source)
	
	print("🧪 Surface: %s + %s → %s (%.1fs) [%s]" % [rule.required_state, tags, rule.result_state, rule.result_duration, source])
	
	# 对站在该格上的实体施加 Buff
	if not rule.entity_status_path.is_empty() and _spatial_index:
		var entities := _spatial_index.query_cell(cell)
		for entity in entities:
			var bm := entity.get_node_or_null("BuffManager") as BuffManager
			if bm:
				var buff := load(rule.entity_status_path) as Buff
				if buff:
					bm.apply_buff(buff)


## 获取 cell 上实体应受的 Buff 路径列表（供 InteractionSystem tick 使用）
func get_entity_buffs(cell: Vector2i) -> Array[String]:
	var result: Array[String] = []
	var surf := _surface_scheduler.get_surface(cell)
	var state: String = surf.get("state", "dry")
	
	# 表面状态 → 实体效果映射
	match state:
		"burning":
			result.append("res://runtime/combat/skills/data/burning.tres")
		"frozen":
			result.append("res://runtime/combat/skills/data/frozen.tres")
		"wet":
			result.append("res://runtime/combat/skills/data/wet.tres")
	
	return result


## 获取表面信息（代理）
## 实体-表面交互 tick（低频，每 0.5s 调用一次）
func tick_entity_surface() -> void:
	if not _surface_scheduler or not _spatial_index:
		return
	
	for cell: Vector2i in _surface_scheduler._active_surfaces:
		var buff_paths := get_entity_buffs(cell)
		if buff_paths.is_empty():
			continue
		
		var entities := _spatial_index.query_cell(cell)
		for entity in entities:
			var bm := entity.get_node_or_null("BuffManager") as BuffManager
			if not bm:
				continue
			for path in buff_paths:
				# 只对尚未拥有该状态的实体施加
				var buff := load(path) as Buff
				if buff and not bm.has_buff(buff.status_id):
					bm.apply_buff(buff)


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


func _to_string() -> String:
	return "SurfaceManager(rules=%d, cells=%d)" % [
		_reactions.size(),
		_surface_scheduler._active_surfaces.size() if _surface_scheduler else 0
	]
