extends Area2D
class_name Portal
## 场景传送门 — 玩家进入时切换到目标场景


@export var target_path: String = ""
@export var target_label: String = "进入"
@export var is_region: bool = true   ## 默认区域模式（保留 GameRuntime/Player/HUD），false=全场景替换


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	if target_path.is_empty():
		push_warning("Portal: 未设置 target_path")


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if target_path.is_empty():
		return

	print("🚪 Portal: %s → %s" % [target_label, target_path])

	if is_region:
		_do_region_transition()
	else:
		var packed := load(target_path) as PackedScene
		if packed:
			get_tree().change_scene_to_packed(packed)


func _do_region_transition() -> void:
	var packed := load(target_path) as PackedScene
	if not packed:
		push_error("Portal: 无法加载场景: %s" % target_path)
		return

	# ⚠️ 物理回调中不能直接改树。抓牢所有引用 → 用 lambda 闭包延迟执行
	var game_root: Node = get_tree().current_scene
	var current_region: Node = _find_region_node(game_root)
	var target: String = target_path

	if not current_region:
		push_error("Portal: 找不到可替换的区域节点")
		return

	# Lambda 闭包：在 _on_body_entered 中捕获所有引用，延迟到空闲时执行
	var do_it := func():
		if not is_instance_valid(game_root) or not is_instance_valid(current_region):
			push_error("Portal: 节点已失效，放弃传送")
			return

		game_root.set_meta("saved_region", current_region)
		game_root.remove_child(current_region)

		var new_region := packed.instantiate()
		game_root.add_child(new_region)

		var player := game_root.get_node_or_null("Player") as Node2D
		if player:
			player.global_position = Vector2(100, 0)

		print("🗺️ Portal: %s 已加载" % target)

	do_it.call_deferred()


func _find_region_node(root: Node) -> Node:
	for child in root.get_children():
		if child.name in ["Overworld", "BurningForest"]:
			if child != root.get_node_or_null("GameRuntime"):
				return child
	for child in root.get_children():
		if child is Node2D and child.name not in ["Player", "GameRuntime", "HUDLayer", "InputSetup"]:
			return child
	return null
