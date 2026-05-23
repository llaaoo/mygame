extends Area2D
class_name Portal
## 场景传送门 — 玩家进入时切换到目标场景

@export var target_path: String = ""              ## 目标场景路径（字符串，避免 UID 依赖）
@export var target_label: String = "进入"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if target_path.is_empty():
		push_warning("Portal: 未设置 target_path")


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if target_path.is_empty():
		return
	
	print("🌀 Portal: %s → %s" % [target_label, target_path])
	call_deferred("_do_transition")


func _do_transition() -> void:
	var game_root := get_tree().current_scene
	var region_root := _find_region_root()
	
	if not region_root or not game_root:
		push_error("Portal: 无法定位场景根节点，放弃传送")
		return
	
	# 加载新场景
	var packed := load(target_path) as PackedScene
	if not packed:
		push_error("Portal: 无法加载场景: %s" % target_path)
		return
	
	# 暂存当前区域（只摘除不销毁，ESC 返回时恢复）
	game_root.set_meta("saved_region", region_root)
	game_root.remove_child(region_root)
	
	# 添加新区域
	var new_region := packed.instantiate()
	new_region.name = packed.get_state().get_node_name(0)
	game_root.add_child(new_region)
	
	# 移动玩家到新区域的出生点（避免卡在传送门上）
	var player := game_root.get_node_or_null("Player") as Node2D
	if player:
		player.global_position = Vector2.ZERO
	
	print("🗺️ Portal: 已切换到 %s" % new_region.name)


func _find_region_root() -> Node:
	## 向上遍历，找到 Game 根节点的直接子节点（即当前地图区域）
	var node: Node = get_parent()
	while node and node.get_parent() != get_tree().current_scene:
		node = node.get_parent()
	return node
