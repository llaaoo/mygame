class_name RespawnScheduler
extends Node
## RespawnScheduler — 可破坏物重生倒计时
##
## 低频率（每 5 秒 Dormant 模式 / 每帧 Loaded 模式）
## respawn_time = -1 → 永久消失
## respawn_time = 0 → 切场景时重生
## respawn_time > 0 → N 秒后重生

var _respawn_queue: Array[Dictionary] = []
var _world_state_manager: WorldStateManager = null


func setup(state_mgr: WorldStateManager) -> void:
	_world_state_manager = state_mgr


func enqueue(object_id: String, respawn_at: float) -> void:
	_respawn_queue.append({
		"object_id": object_id,
		"remaining": respawn_at
	})


func tick(delta: float) -> void:
	if _respawn_queue.is_empty():
		return
	
	var to_remove: Array[int] = []
	
	for i: int in range(_respawn_queue.size()):
		var entry: Dictionary = _respawn_queue[i]
		entry["remaining"] = entry["remaining"] - delta
		
		if entry["remaining"] <= 0.0:
			var object_id: String = entry["object_id"]
			# 通知 WorldStateManager 重生（数据层）
			if _world_state_manager:
				_world_state_manager.update_state(object_id, {
					"state": "INTACT",
					"hp": _world_state_manager.get_state(object_id).get("max_hp", 10),
					"respawn_at": 0.0
				})
			# 通知 MapObject 节点重生（表现层）
			_restore_map_object(object_id)
			to_remove.append(i)
	
	# 倒序移除
	for i: int in range(to_remove.size() - 1, -1, -1):
		_respawn_queue.remove_at(to_remove[i])


## 通过 instance_id 找到 MapObject 节点并恢复其表现层状态
func _restore_map_object(object_id: String) -> void:
	var instance_id := object_id.to_int()
	var obj := instance_from_id(instance_id) as MapObject
	if obj and is_instance_valid(obj):
		var state := _world_state_manager.get_state(object_id) if _world_state_manager else {}
		obj.restore_state(state)
		# 重新注册到空间索引（刚才被 destroy 时注销了）
		obj._register_with_world_runtime()
		print("♻️ RespawnScheduler: %s 已重生" % obj.name)


func _to_string() -> String:
	return "RespawnScheduler(pending=%d)" % _respawn_queue.size()
