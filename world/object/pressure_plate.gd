class_name PressurePlate
extends Area2D
## 压力板 — 实体站上去时自动向目标发送信号
##
## 实体进入 → "activate"
## 实体离开 → "deactivate"


@export var target: NodePath


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # ACTOR
	monitoring = true
	
	# 创建碰撞形状（场景中的 CollisionShape2D 无 shape）
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 32)
		shape_node.shape = rect
	
	# fallback：若 target 未在场景中设置，自动扫描兄弟节点找 SignalReceiver
	if target.is_empty():
		_auto_find_target()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _auto_find_target() -> void:
	var parent := get_parent()
	if not parent:
		return
	for sibling in parent.get_children():
		if sibling == self:
			continue
		var receiver := sibling.get_node_or_null("SignalReceiver") as SignalReceiver
		if receiver:
			target = sibling.get_path()
			return


func _on_body_entered(_body: Node2D) -> void:
	_send_signal("activate")


func _on_body_exited(_body: Node2D) -> void:
	_send_signal("deactivate")


func _send_signal(signal_id: String) -> void:
	if target.is_empty():
		return
	var target_node := get_node_or_null(target)
	if not target_node:
		return
	var receiver := target_node as SignalReceiver
	if not receiver:
		receiver = target_node.get_node_or_null("SignalReceiver") as SignalReceiver
	if receiver:
		receiver.receive_signal(signal_id)
