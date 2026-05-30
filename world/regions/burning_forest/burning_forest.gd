extends Node2D

const OVERWORLD_PATH := "res://world/maps/overworld.tscn"
const OVERWORLD_RETURN_MARKER := "overworld_from_forest"


func _ready() -> void:
	print("BurningForest ready")
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
	print("BurningForest quest started")


func _restore_overworld() -> void:
	var gr := GameRuntime.instance
	if not gr or not gr.get_region_runtime():
		push_error("BurningForest: RegionRuntime unavailable")
		return
	gr.get_region_runtime().ensure_region(OVERWORLD_PATH, OVERWORLD_RETURN_MARKER)
