extends Node
## 项目健康验证脚本 —— 在编辑器中运行此脚本检查核心功能
## 使用方式: main.tscn 中临时挂载此脚本，运行游戏查看输出

const SEPARATOR = "=================================================="

func _ready() -> void:
	print(SEPARATOR)
	print("🔍 项目健康验证报告")
	print(SEPARATOR)

	_validate_main_scene()
	_validate_player()
	_validate_state_machine()
	_validate_skills()
	_validate_input()

	print(SEPARATOR)
	print("✅ 验证完成！窗口将在 5 秒后自动关闭...")
	print(SEPARATOR)

	# 等待 5 秒让用户看清输出再退出
	await get_tree().create_timer(5.0).timeout
	get_tree().quit()

func _validate_main_scene() -> void:
	print("\n--- 主场景验证 ---")
	var game = get_tree().current_scene
	if game and game.name == "Game":
		print("✅ main.tscn 根节点 'Game' 存在")
	else:
		print("❌ main.tscn 根节点异常")

	var overworld = game.get_node_or_null("Overworld")
	print("✅ Overworld 场景: %s" % ["存在" if overworld else "缺失"])

	var player = game.get_node_or_null("Player")
	print("✅ Player 节点: %s" % ["存在" if player else "缺失"])

func _validate_player() -> void:
	print("\n--- Player 验证 ---")
	var player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		print("❌ 找不到 Player 节点")
		return

	# 检查关键方法是否存在
	var methods_to_check = ["perform_melee_attack", "cast_skill", "get_mouse_direction"]
	for method in methods_to_check:
		if player.has_method(method):
			print("✅ 方法 '%s()' 存在" % method)
		else:
			print("❌ 方法 '%s()' 缺失 —— 运行时会崩溃！" % method)

	# 检查关键属性
	if "move_speed" in player:
		print("✅ 属性 move_speed = %s" % player.move_speed)
	if "attack_damage" in player:
		print("✅ 属性 attack_damage = %s" % player.attack_damage)
	if player.has_method("cast_skill"):
		print("✅ 方法 cast_skill() 存在")

	# 检查子节点
	var children = ["Sprite2D", "CollisionShape2D", "Camera2D", "AnimationPlayer", "AttackHitbox", "StateMachine"]
	for child_name in children:
		if player.get_node_or_null(child_name):
			print("✅ 子节点 '%s' 存在" % child_name)
		else:
			print("❌ 子节点 '%s' 缺失" % child_name)

func _validate_state_machine() -> void:
	print("\n--- StateMachine 验证 ---")
	var player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		return

	var sm = player.get_node_or_null("StateMachine")
	if not sm:
		print("❌ StateMachine 节点缺失")
		return
	print("✅ StateMachine 节点存在")

	# 检查脚本
	if not sm.get_script():
		print("❌ StateMachine 脚本未挂载")
		return
	print("✅ StateMachine 脚本已挂载: %s" % sm.get_script().resource_path)

	# 检查 initial_state
	if sm.get("initial_state") != null:
		print("✅ initial_state 已设置: %s" % sm.initial_state.name)
	else:
		print("⚠️ initial_state 未设置（将使用自动回退）")

	# 检查所有状态子节点
	var expected_states = ["Idle", "Move", "Attack", "Dodge", "Skill"]
	for state_name in expected_states:
		var state = sm.get_node_or_null(state_name)
		if state:
			var script_path = state.get_script().resource_path if state.get_script() else "无脚本"
			print("✅ 状态 '%s' 存在 [脚本: %s]" % [state_name, script_path])
		else:
			print("❌ 状态 '%s' 缺失" % state_name)

func _validate_skills() -> void:
	print("\n--- 技能验证 ---")
	var fireball = load("res://skills/scenes/fireball.tscn")
	if fireball:
		print("✅ fireball.tscn 可加载")
		var instance = fireball.instantiate()
		if instance is Area2D:
			print("✅ fireball 根节点类型为 Area2D")
		if instance.has_method("set_direction"):
			print("✅ fireball 拥有 set_direction() 方法")
		if instance.has_signal("body_entered"):
			print("✅ fireball 拥有 body_entered 信号")
		instance.queue_free()
	else:
		print("❌ fireball.tscn 无法加载")

func _validate_input() -> void:
	print("\n--- 输入映射验证 ---")
	var actions = ["move_left", "move_right", "move_up", "move_down", "attack", "dodge", "skill"]
	for action in actions:
		if InputMap.has_action(action):
			print("✅ 输入动作 '%s' 已注册" % action)
		else:
			print("❌ 输入动作 '%s' 未注册 —— 将无法操作！" % action)
