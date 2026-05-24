class_name MapObject
extends Node2D
## 地图物体基类 — 仅 Damageable + Interactable + Persistent + Taggable
## 不做 AI、不做 Buffable、不做 AbilityUser、不做 Inventory

signal destroyed(object_id: String)
signal damaged(object_id: String, hp_remaining: int, hp_max: int)

@export var object_data: MapObjectData

var _object_id: String
var _current_hp: int
var _state: String = "INTACT"  ## INTACT / DAMAGED / DESTROYED / RESPAWNING
var _respawn_timer: float = 0.0


func _ready() -> void:
	if not object_data:
		object_data = MapObjectData.new()
		object_data.display_name = name
	_object_id = str(get_instance_id())
	_current_hp = object_data.max_hp
	_apply_visual()
	_register_with_world_runtime()
	



## 公开 object_id
func get_object_id() -> String:
	return _object_id


## --- Damageable 接口 ---

func take_damage(amount: int) -> void:
	if _state == "DESTROYED" or _state == "RESPAWNING":
		return
	
	_current_hp = maxi(0, _current_hp - amount)
	damaged.emit(_object_id, _current_hp, object_data.max_hp)
	
	if _current_hp <= 0:
		_on_destroyed()
	else:
		_flash_hit()


func get_tags() -> Array[String]:
	return object_data.tags


func get_hp() -> int:
	return _current_hp


func get_max_hp() -> int:
	return object_data.max_hp


## --- Interactable 接口 ---

func interact() -> void:
	if object_data.is_interactable and _state == "INTACT":
		_on_interact()


## --- Persistent 接口 ---

func get_state() -> Dictionary:
	return {
		"id": _object_id,
		"state": _state,
		"hp": _current_hp,
		"max_hp": object_data.max_hp,
		"respawn_at": _respawn_timer if _state == "RESPAWNING" else 0.0
	}


func restore_state(data: Dictionary) -> void:
	_current_hp = data.get("hp", object_data.max_hp)
	_state = data.get("state", "INTACT")
	_respawn_timer = data.get("respawn_at", 0.0)
	_apply_visual()
	if _state == "INTACT":
		_restore_collision()


## --- 内部 ---

func _on_destroyed() -> void:
	_state = "DESTROYED"
	
	# 空间索引维护例外：register/unregister 保留直接调用（性能关键路径）
	var wr: WorldRuntime = _get_world_runtime()
	if wr:
		wr.unregister_object(self)
	
	destroyed.emit(_object_id)
	
	# 破坏特效 + 掉落物（本地表现，非跨 Runtime）
	if object_data.destruction_effect_scene:
		var effect: Node = object_data.destruction_effect_scene.instantiate()
		effect.global_position = global_position
		get_parent().add_child(effect)
	if object_data.destruction_loot_scene:
		var loot: Node = object_data.destruction_loot_scene.instantiate()
		loot.global_position = global_position
		get_parent().add_child(loot)
	
	# 通过 CommandBus 异步路由到 WorldRuntime / SimulationRuntime（始终发射）
	_emit_destroyed_command()
	
	# 重生倒计时
	if object_data.respawn_time == -1.0:
		_apply_visual()
	elif object_data.respawn_time == 0.0:
		pass  # 切场景时重生
	else:
		_state = "RESPAWNING"
		_respawn_timer = object_data.respawn_time
		_apply_visual()
	
	# 路径阻挡移除
	if object_data.blocks_path:
		_remove_collision()


## 通过 CommandBus 发送 world/destroyed 命令（替代直接调用 SimulationRuntime）
func _emit_destroyed_command() -> void:
	var gr := GameRuntime.instance
	if not gr:
		return
	var bus := gr.get_command_bus()
	if not bus:
		return
	
	var cmd := RuntimeCommand.create(
		RuntimeCommand.TYPE_DESTROYED,
		object_data.display_name,
		RuntimeCommand.Target.WORLD,
		{
			"object_id": _object_id,
			"state_data": get_state(),
			"position": global_position,
			"respawn_time": object_data.respawn_time,
			"destruction_radius": object_data.destruction_radius,
			"destruction_aoe_damage": object_data.destruction_aoe_damage,
			"destruction_aoe_tags": object_data.destruction_aoe_tags,
			"destruction_surface": object_data.destruction_surface,
			"destruction_surface_radius": object_data.destruction_surface_radius,
		}
	)
	bus.emit(cmd)


func _register_with_world_runtime() -> void:
	var wr: WorldRuntime = _get_world_runtime()
	if wr:
		wr.register_object(self)
	else:
		# GameRuntime._ready() 尚未完成，延迟重试
		call_deferred("_register_with_world_runtime")


## 通过 GameRuntime.instance 获取 WorldRuntime（不再硬编码路径）
func _get_world_runtime() -> WorldRuntime:
	var gr := GameRuntime.instance
	if gr:
		return gr.get_world_runtime()
	return null


func _restore_collision() -> void:
	# 恢复 Body 碰撞体
	var body := get_node_or_null("Body")
	if body:
		for shape_child in body.get_children():
			if shape_child is CollisionShape2D or shape_child is CollisionPolygon2D:
				shape_child.set_deferred("disabled", false)
	# 恢复 HitArea
	var hit_area := get_node_or_null("HitArea")
	if hit_area:
		for shape_child in hit_area.get_children():
			if shape_child is CollisionShape2D or shape_child is CollisionPolygon2D:
				shape_child.set_deferred("disabled", false)
		hit_area.set_deferred("monitoring", true)
		hit_area.set_deferred("monitorable", true)
	# 直接子节点的碰撞形状
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", false)


func _remove_collision() -> void:
	# 禁用物理阻挡体（StaticBody2D → CollisionShape2D）
	var body := get_node_or_null("Body")
	if body:
		for shape_child in body.get_children():
			if shape_child is CollisionShape2D or shape_child is CollisionPolygon2D:
				shape_child.set_deferred("disabled", true)
	# 禁用 HitArea（防止已销毁物体继续被投射物命中）
	var hit_area := get_node_or_null("HitArea")
	if hit_area:
		for shape_child in hit_area.get_children():
			if shape_child is CollisionShape2D or shape_child is CollisionPolygon2D:
				shape_child.set_deferred("disabled", true)
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)
	# 兼容旧结构：直接子节点的碰撞形状
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)


func _flash_hit() -> void:
	if has_node("Sprite2D"):
		var sprite: Sprite2D = $Sprite2D
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.08).timeout
		sprite.modulate = Color.WHITE


func _on_interact() -> void:
	pass  # 子类覆写


func _apply_visual() -> void:
	match _state:
		"INTACT":
			visible = true
		"DAMAGED":
			visible = true
		"DESTROYED":
			visible = false
		"RESPAWNING":
			visible = false
