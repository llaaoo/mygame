extends Node2D
## 燃烧森林 — ESC 返回主世界（恢复暂存的原始区域）


func _ready() -> void:
	print("🔥 燃烧森林 | ESC 返回主世界")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_restore_overworld()


func _restore_overworld() -> void:
	var game_root := get_tree().current_scene
	if not game_root:
		push_error("BurningForest: current_scene 为空！")
		return
	
	var saved := game_root.get_meta("saved_region") as Node
	if not saved:
		push_error("BurningForest: 没有暂存的区域可恢复！")
		return
	
	# 从树中摘除自己
	game_root.remove_child(self)
	queue_free()
	
	# 恢复原始区域
	game_root.add_child(saved)
	game_root.remove_meta("saved_region")
	
	# 移动玩家到安全位置
	var player := game_root.get_node_or_null("Player") as Node2D
	if player:
		player.global_position = Vector2.ZERO
	
	print("🗺️ BurningForest: 已恢复原始 Overworld")
