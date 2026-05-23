class_name Door
extends MapObject
## 门 — MapObject + SignalReceiver
##
## 可被开关/压力板控制开关
## 关闭时 blocks_path（不可通行），打开时解除阻挡
## 可被破坏（继承 MapObject 的 damage 系统）


func _ready() -> void:
	# fallback：场景实例化时 object_data 可能未持久化，加载默认数据
	if not object_data:
		object_data = load("res://world/doors/door_data.tres") as MapObjectData
	super._ready()
	# 注册 SignalReceiver 接口
	var receiver := SignalReceiver.new()
	receiver.name = "SignalReceiver"
	receiver.set_callback(_on_signal)
	add_child(receiver)


## --- SignalReceiver ---

func _on_signal(signal_id: String) -> void:
	match signal_id:
		"activate":
			_open()
		"deactivate":
			_close()
		"toggle":
			if _state == "INTACT":
				_close() if _is_open() else _open()


## --- 开关逻辑 ---

func _open() -> void:
	if not _is_open():
		_remove_collision()
		_state = "DAMAGED"  # 复用 DAMAGED 表示"打开"
		_apply_visual()


func _close() -> void:
	if _is_open():
		_enable_collision()
		_state = "INTACT"
		_apply_visual()


func _is_open() -> bool:
	return _state == "DAMAGED"


## --- 碰撞开关 ---

func _enable_collision() -> void:
	var body := get_node_or_null("Body")
	if body:
		for child in body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)


## --- 视觉覆写 ---

func _apply_visual() -> void:
	if _is_open():
		visible = false
	else:
		super._apply_visual()
