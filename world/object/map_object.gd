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
		"respawn_at": _respawn_timer if _state == "RESPAWNING" else 0.0
	}


func restore_state(data: Dictionary) -> void:
	_current_hp = data.get("hp", object_data.max_hp)
	_state = data.get("state", "INTACT")
	_respawn_timer = data.get("respawn_at", 0.0)
	_apply_visual()


## --- 内部 ---

func _on_destroyed() -> void:
	_state = "DESTROYED"
	
	# 从空间索引注销
	var wr: WorldRuntime = _find_world_runtime()
	if wr:
		wr.unregister_object(self)
	
	destroyed.emit(_object_id)
	
	# 破坏特效
	if object_data.destruction_effect_scene:
		var effect: Node = object_data.destruction_effect_scene.instantiate()
		effect.global_position = global_position
		get_parent().add_child(effect)
	
	# 掉落物
	if object_data.destruction_loot_scene:
		var loot: Node = object_data.destruction_loot_scene.instantiate()
		loot.global_position = global_position
		get_parent().add_child(loot)
	
	# AOE 伤害（油桶引爆等）
	if object_data.destruction_radius > 0:
		_trigger_destruction_aoe()
	
	# 表面生成（油桶破坏 → oiled）
	if not object_data.destruction_surface.is_empty() and object_data.destruction_surface_radius > 0.0:
		_spawn_destruction_surface()
	
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


func _trigger_destruction_aoe() -> void:
	var world_runtime: WorldRuntime = _find_world_runtime()
	
	if world_runtime and CombatExecutor.instance:
		var targets: Array = world_runtime.spatial_index.query_radius(
			global_position, object_data.destruction_radius
		)
		var valid_targets: Array = []
		for t in targets:
			if t != self and t.has_method("take_damage"):
				valid_targets.append(t)
		
		if valid_targets.is_empty():
			return
		
		var names: Array[String] = []
		for t in valid_targets:
			names.append(t.name)
			CombatExecutor.report_hit(
				self, t, object_data.destruction_aoe_damage,
				global_position, null, object_data.destruction_aoe_tags
			)
			t.take_damage(object_data.destruction_aoe_damage)
		
		print("💥 AOE: %s → %d目标 (r=%.0f): %s" % [object_data.display_name, valid_targets.size(), object_data.destruction_radius, ", ".join(names)])


func _register_with_world_runtime() -> void:
	var wr: WorldRuntime = _find_world_runtime()
	if wr:
		wr.register_object(self)


func _find_world_runtime() -> WorldRuntime:
	var root := get_tree().root
	# 路径: Game/GameRuntime/WorldRuntime
	if root.has_node("Game/GameRuntime/WorldRuntime"):
		return root.get_node("Game/GameRuntime/WorldRuntime")
	# Fallback: 直接路径
	if root.has_node("GameRuntime/WorldRuntime"):
		return root.get_node("GameRuntime/WorldRuntime")
	return null


## 破坏时在半径内生成表面
func _spawn_destruction_surface() -> void:
	var sm := SurfaceManager.instance
	if not sm:
		return
	
	var cell_radius := ceili(object_data.destruction_surface_radius / 64.0) + 1
	var center := Vector2i(floori(global_position.x / 64), floori(global_position.y / 64))
	
	for dx in range(-cell_radius, cell_radius + 1):
		for dy in range(-cell_radius, cell_radius + 1):
			var cell := Vector2i(center.x + dx, center.y + dy)
			var dist := global_position.distance_to(Vector2(cell.x * 64 + 32, cell.y * 64 + 32))
			if dist <= object_data.destruction_surface_radius:
				sm.force_set_surface(cell, object_data.destruction_surface, 10.0, "destroyed_%s" % object_data.display_name)
	
	print("💥 MapObject: %s 破坏，生成 %s 表面 (r=%.0f)" % [object_data.display_name, object_data.destruction_surface, object_data.destruction_surface_radius])
	
	# 立即在表面格上应用 AOE 标签触发 ReactionRule（如 oiled + fire → burning）
	if not object_data.destruction_aoe_tags.is_empty():
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				var cell := Vector2i(center.x + dx, center.y + dy)
				var dist := global_position.distance_to(Vector2(cell.x * 64 + 32, cell.y * 64 + 32))
				if dist <= object_data.destruction_surface_radius:
					sm.apply_tags(cell, object_data.destruction_aoe_tags, "aoe_%s" % object_data.display_name)


func _remove_collision() -> void:
	# 禁用物理阻挡体（StaticBody2D → CollisionShape2D）
	var body := get_node_or_null("Body")
	if body:
		for shape_child in body.get_children():
			if shape_child is CollisionShape2D or shape_child is CollisionPolygon2D:
				shape_child.set_deferred("disabled", true)
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
