class_name StateMachine
extends Node

@export var initial_state: Node

var current_state: Node
var states: Dictionary = {}

func _ready() -> void:
	# 直接初始化，不使用 await（避免 coroutine 被 GC）
	for child in get_children():
		var is_state = child is State or child.has_method("enter")
		print("   - 子节点: ", child.name, ", 脚本: ", child.get_script(), ", is State: ", is_state)
		if is_state:
			states[child.name.to_lower()] = child
			if child.has_signal("transitioned") and not child.transitioned.is_connected(on_child_transition):
				child.transitioned.connect(on_child_transition)
			child.set("entity", owner)
			print("     ✅ 已注册状态: ", child.name)
	
	if initial_state:
		current_state = initial_state
		print("🔍 StateMachine: 使用 initial_state: ", current_state.name)
	else:
		# 自动使用第一个 State 子节点作为初始状态
		for child in get_children():
			if child is State or child.has_method("enter"):
				current_state = child
				print("🔍 StateMachine: 自动使用首个状态: ", current_state.name)
				break
	
	if not current_state:
		print("❌ StateMachine: 没有找到任何状态！")
		return
	
	if current_state:
		current_state.enter()
		print("🔍 StateMachine: 已进入初始状态: ", current_state.name)
	
	# 确保 Camera2D 是当前相机
	var cam = owner.get_node_or_null("Camera2D") if owner else null
	if cam and cam is Camera2D:
		cam.enabled = true

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func on_child_transition(state: Node, new_state_name: String) -> void:
	if state != current_state:
		return
	
	var new_state = states.get(new_state_name.to_lower())
	if not new_state:
		printerr("StateMachine: State '%s' does not exist." % new_state_name)
		return
	
	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state

## 强制切换到指定状态（用于外部触发）
func transition_to(state_name: String) -> void:
	var new_state = states.get(state_name.to_lower())
	if not new_state:
		printerr("StateMachine: State '%s' does not exist." % state_name)
		return
	
	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state
