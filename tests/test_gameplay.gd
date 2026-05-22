extends SceneTree

## 快速功能测试脚本
## 运行方式: godot --script res://tests/test_gameplay.gd

func _init() -> void:
	print("=".repeat(60))
	print("🧪 开始功能测试")
	print("=".repeat(60))

	# 加载主场景
	var main_scene = load("res://main.tscn")
	if not main_scene:
		print("❌ 无法加载 main.tscn")
		quit(1)
		return

	var game = main_scene.instantiate()
	root.add_child(game)
	await get_tree().process_frame

	# 查找玩家
	var player = game.get_node_or_null("Player")
	if not player:
		print("❌ Player 节点不存在")
		quit(1)
		return
	print("✅ Player 节点存在")

	# 检查 StateMachine
	var sm = player.get_node_or_null("StateMachine")
	if not sm:
		print("❌ StateMachine 节点不存在")
		quit(1)
		return
	print("✅ StateMachine 节点存在")

	# 检查 StateMachine 脚本
	if sm.get_script():
		print("✅ StateMachine 脚本已挂载: ", sm.get_script().resource_path)
	else:
		print("❌ StateMachine 脚本未挂载")
		quit(1)
		return

	# 手动初始化状态机
	sm._ready()

	# 检查当前状态
	var cur = sm.get("current_state")
	if cur:
		print("✅ 当前状态: ", cur.name)
	else:
		print("❌ 无当前状态")
		quit(1)
		return

	# 检查所有状态子节点
	var expected_states = ["idle", "move", "attack", "dodge", "skill"]
	var states_dict = sm.get("states")
	if states_dict:
		for state_name in expected_states:
			if state_name in states_dict:
				print("✅ 状态已注册: ", state_name)
			else:
				print("❌ 状态未注册: ", state_name)
				quit(1)
				return
	else:
		print("❌ 状态字典未找到")
		quit(1)
		return

	# 测试输入映射
	var input_actions = ["move_left", "move_right", "move_up", "move_down", "attack", "dodge", "skill"]
	for action in input_actions:
		if InputMap.has_action(action):
			print("✅ 输入动作已注册: ", action)
		else:
			print("❌ 输入动作未注册: ", action)

	print("=".repeat(60))
	print("🎉 所有核心检查通过！")
	print("=".repeat(60))

	# 清理
	await get_tree().create_timer(1.0).timeout
	quit(0)
