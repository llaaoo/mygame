extends Node
## 自动注册输入映射（避免手动配置 Input Map）

func _enter_tree() -> void:
	_setup_action("move_left", KEY_A)
	_setup_action("move_right", KEY_D)
	_setup_action("move_up", KEY_W)
	_setup_action("move_down", KEY_S)
	_setup_action("dodge", KEY_SPACE)
	_setup_action("attack", MOUSE_BUTTON_LEFT)
	_setup_action("skill", MOUSE_BUTTON_RIGHT)

func _setup_action(action_name: String, primary_key) -> void:
	if InputMap.has_action(action_name):
		return
	
	InputMap.add_action(action_name)
	
	var event: InputEvent
	if primary_key is Key:
		event = InputEventKey.new()
		event.keycode = primary_key
	elif primary_key is MouseButton:
		event = InputEventMouseButton.new()
		event.button_index = primary_key
	
	if event:
		InputMap.action_add_event(action_name, event)
