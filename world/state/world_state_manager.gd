class_name WorldStateManager
extends Node
## WorldStateManager — 真实世界状态管理器
##
## WorldState 是真实状态，SceneTree 只是它的视觉表现。
## MapObject 的持久化状态在这里维护，不依赖 SceneTree。
##
## 生命周期状态机:
##   INTACT → (HP≤0) → DESTROYED → (倒计时结束) → RESPAWNING → (重生) → INTACT
##   DESTROYED → (respawn_time=-1) → 永久消失

signal state_changed(object_id: String, old_state: String, new_state: String)

## _object_states: Dictionary[String, Dictionary]
##   每个 MapObject 的状态快照: {"state": "INTACT", "hp": 10, "respawn_at": 0.0}
var _object_states: Dictionary = {}

## 已销毁但等待重生的对象
var _respawn_queue: Array[Dictionary] = []


## 注册 MapObject 状态
func register(obj: MapObject) -> void:
	var id: String = obj.get_object_id()
	if _object_states.has(id):
		# 恢复已持久化的状态
		obj.restore_state(_object_states[id])
	else:
		# 首次注册，记录初始状态
		_object_states[id] = obj.get_state()


## 注销 MapObject
func unregister(object_id: String) -> void:
	# 保留状态（用于 Dormant 恢复）
	pass


## 更新状态（由 MapObject 调用）
func update_state(object_id: String, state_data: Dictionary) -> void:
	var old: String = _object_states.get(object_id, {}).get("state", "INTACT")
	_object_states[object_id] = state_data
	var new: String = state_data.get("state", "INTACT")
	
	if old != new:
		state_changed.emit(object_id, old, new)


## 获取状态
func get_state(object_id: String) -> Dictionary:
	return _object_states.get(object_id, {})


## 获取全部状态快照（供 SaveManager 序列化）
func get_all_states() -> Dictionary:
	return _object_states.duplicate()


## 批量恢复状态（供 SaveManager 反序列化）
func set_all_states(data: Dictionary) -> void:
	_object_states = data.duplicate()


## 获取区域内所有状态
func get_states_in_radius(pos: Vector2, radius: float, spatial_index: WorldSpatialIndex) -> Dictionary:
	var result := {}
	var objects: Array = spatial_index.query_radius(pos, radius)
	for obj in objects:
		var id: String = obj.get_object_id()
		if _object_states.has(id):
			result[id] = _object_states[id]
	return result


## 重生倒计时（由 SimulationRuntime.respawn_scheduler 调用）
func tick_respawn(delta: float) -> void:
	var to_respawn: Array[String] = []
	
	for id: String in _object_states:
		var data: Dictionary = _object_states[id]
		if data.get("state", "") == "RESPAWNING":
			var remaining: float = data.get("respawn_at", 0.0) - delta
			if remaining <= 0.0:
				to_respawn.append(id)
			else:
				data["respawn_at"] = remaining
	
	for id: String in to_respawn:
		_object_states[id] = {"state": "INTACT", "hp": _get_max_hp_for(id), "respawn_at": 0.0}
		state_changed.emit(id, "RESPAWNING", "INTACT")


func _get_max_hp_for(object_id: String) -> int:
	return _object_states.get(object_id, {}).get("max_hp", 10)


func _to_string() -> String:
	return "WorldStateManager(objects=%d)" % _object_states.size()
