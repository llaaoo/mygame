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
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(_body: Node2D) -> void:
	_send_signal("activate")


func _on_body_exited(_body: Node2D) -> void:
	_send_signal("deactivate")


func _send_signal(signal_id: String) -> void:
	if target.is_empty():
		return
	var target_node := get_node(target)
	if not target_node:
		return
	var receiver := target_node as SignalReceiver
	if not receiver:
		receiver = target_node.get_node_or_null("SignalReceiver") as SignalReceiver
	if receiver:
		receiver.receive_signal(signal_id)
