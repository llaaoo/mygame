extends Node2D
## 燃烧森林 — ESC 返回主世界 + 场景 Quest


func _ready() -> void:
	print("🔥 燃烧森林 | ESC 返回主世界")
	call_deferred("_start_burning_forest_quest")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_restore_overworld()


func _start_burning_forest_quest() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var qm: QuestManager = player.get("quest_manager")
	if not qm:
		return
	
	# 避免重复接任务
	if qm.is_completed("burning_forest"):
		return
	for q in qm.get_active_quests():
		if q.data.quest_id == "burning_forest":
			return
	
	var data := QuestData.new()
	data.quest_id = "burning_forest"
	data.title = "清除燃烧森林"
	data.description = "击败森林中的亡灵，清除威胁。"
	
	var stage1 := QuestStageData.new()
	stage1.stage_id = "hunt"
	var obj1 := KillObjective.new()
	obj1.target_tag = "enemy"
	obj1.required_count = 4
	stage1.objectives.append(obj1)
	data.stages.append(stage1)
	
	qm.start_quest(data)
	print("📋 燃烧森林任务已接取")


func _restore_overworld() -> void:
	var game_root := get_tree().current_scene
	if not game_root:
		push_error("BurningForest: current_scene 为空！")
		return
	
	var saved := game_root.get_meta("saved_region") as Node
	if not saved:
		push_error("BurningForest: 没有暂存的区域可恢复！")
		return
	
	game_root.remove_child(self)
	queue_free()
	game_root.add_child(saved)
	game_root.remove_meta("saved_region")
	
	var player := game_root.get_node_or_null("Player") as Node2D
	if player:
		player.global_position = Vector2.ZERO
	
	print("🗺️ BurningForest: 已恢复原始 Overworld")
