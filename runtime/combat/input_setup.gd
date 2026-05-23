extends Node
## 自动注册输入映射（运行时 fallback，避免手动配置 Input Map）

func _enter_tree() -> void:
	_setup_key_action("move_left", KEY_A)
	_setup_key_action("move_right", KEY_D)
	_setup_key_action("move_up", KEY_W)
	_setup_key_action("move_down", KEY_S)
	_setup_key_action("dodge", KEY_SPACE)
	_setup_mouse_action("attack", MOUSE_BUTTON_LEFT)
	_setup_mouse_action("skill", MOUSE_BUTTON_RIGHT)
	_setup_key_action("skill_1", KEY_1)
	_setup_key_action("skill_2", KEY_2)
	_setup_key_action("skill_3", KEY_3)
	_setup_key_action("skill_4", KEY_4)


func _setup_key_action(action_name: String, key: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.keycode = key
	InputMap.action_add_event(action_name, event)


func _setup_mouse_action(action_name: String, button: MouseButton) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)
