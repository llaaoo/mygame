class_name Pickup
extends Area2D
## 可拾取物基类 — 高扩展性设计
##
## 子类只需覆写 _on_collected(player) 即可定义拾取效果。
## 碰撞检测、queue_free 由基类统一处理。

## 拾取值（子类可复用或忽略）
@export var value: float = 1.0

## 拾取后是否自动销毁
@export var auto_destroy: bool = true

## 拾取冷却（防止重复拾取）
@export var cooldown: float = 0.0
var _collectible: bool = true


func _ready() -> void:
	# 碰撞层：掉落物检测 ACTOR（玩家）
	collision_layer = 512  # ITEM
	collision_mask = 2     # ACTOR
	body_entered.connect(_on_body_entered)
	_setup_shape()


func _setup_shape() -> void:
	# 确保有有效的碰撞形状
	for child in get_children():
		if child is CollisionShape2D and child.shape != null:
			return
		if child is CollisionPolygon2D and child.polygon != null:
			return
	# 无有效形状则自动创建
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	shape_node.shape = circle
	add_child(shape_node)


func _on_body_entered(body: Node2D) -> void:
	if not _collectible:
		return
	if not body.is_in_group("player"):
		return

	_collectible = false
	_on_collected(body as Player)

	if auto_destroy:
		queue_free()
	elif cooldown > 0:
		await get_tree().create_timer(cooldown).timeout
		_collectible = true


## 覆写此方法定义拾取效果
func _on_collected(_player: Player) -> void:
	pass
