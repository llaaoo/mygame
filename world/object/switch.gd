class_name Switch
extends Node2D
## 开关 — 玩家按 E 交互，向目标发送信号
##
## 配置: target 指向场景中任意 SignalReceiver 节点
## 标准信号: "activate"（打开）/ "deactivate"（关闭）交替


@export var target: NodePath

var _is_on: bool = false


func _ready() -> void:
	add_to_group("interactable")
	# 将 Interactable 接口注册为子节点
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.set_callback(_on_interact)
	add_child(interactable)


func _on_interact(_actor: Node2D) -> void:
	_is_on = not _is_on
	var signal_id := "activate" if _is_on else "deactivate"
	_send_signal(signal_id)
	_update_visual()


func is_activated() -> bool:
	return _is_on


func _send_signal(signal_id: String) -> void:
	var receiver := _find_receiver()
	if receiver:
		receiver.receive_signal(signal_id)


func _find_receiver() -> SignalReceiver:
	# 1. 优先使用显式 target
	if not target.is_empty():
		var target_node := get_node(target)
		if target_node:
			var r := target_node as SignalReceiver
			if not r:
				r = target_node.get_node_or_null("SignalReceiver") as SignalReceiver
			if r:
				return r

	# 2. Fallback: 扫描兄弟节点找 SignalReceiver
	var parent := get_parent()
	if parent:
		for sibling in parent.get_children():
			if sibling == self:
				continue
			var r := sibling.get_node_or_null("SignalReceiver") as SignalReceiver
			if r:
				return r
	return null


func _update_visual() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.modulate = Color.GREEN if _is_on else Color.RED
