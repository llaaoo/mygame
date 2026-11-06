class_name QuestRuntime
extends RefCounted

enum QuestState { NOT_STARTED, ACTIVE, COMPLETED, FAILED }

var data: QuestData
var state: QuestState = QuestState.NOT_STARTED
var current_stage: int = 0
var _progress: Dictionary={}


func start() -> void:
	state = QuestState.ACTIVE
	current_stage = 0
	_reset_all_objectives()
	_activate_current_stage_objectives()


func restore(stage_index: int, progress: Array) -> void:
	state = QuestState.ACTIVE
	current_stage = clampi(stage_index, 0, maxi(0, data.stages.size() - 1))
	_reset_all_objectives()
	var index := 0
	for stage in data.stages:
		for obj in stage.objectives:
			if index < progress.size():
				_progress[obj] = clampi(int(progress[index]), 0, obj.required_count)
			index += 1
	_activate_current_stage_objectives()


func on_event(ev: CombatEvent) -> void:
	if state != QuestState.ACTIVE or data.stages.is_empty():
		return

	for obj in _current_stage_data().objectives:
		_try_progress(obj, ev)

	for stage_index in range(current_stage + 1, data.stages.size()):
		for obj in data.stages[stage_index].objectives:
			if obj.track_from_start:
				_try_progress(obj, ev)

	while _all_done():
		if current_stage < data.stages.size() - 1:
			current_stage += 1
			_activate_current_stage_objectives()
		else:
			state = QuestState.COMPLETED
			break


func get_progress() -> Array[int]:
	var result: Array[int] = []
	if data.stages.is_empty():
		return result
	for obj in _current_stage_data().objectives:
		result.append(int(_progress.get(obj,0)))
	return result


func get_all_progress() -> Array[int]:
	var result: Array[int] = []
	for stage in data.stages:
		for obj in stage.objectives:
			result.append(int(_progress.get(obj,0)))
	return result


func _reset_all_objectives() -> void:
	for stage in data.stages:
		for obj in stage.objectives:
			_progress[obj]=0


func _current_stage_data() -> QuestStageData:
	return data.stages[current_stage]


func _try_progress(obj: QuestObjective, ev: CombatEvent) -> void:
	if int(_progress.get(obj,0))>=obj.required_count:
		return
	_progress[obj]=mini(obj.required_count,int(_progress.get(obj,0))+obj.progress_for_event(ev))


func _activate_current_stage_objectives() -> void:
	if data.stages.is_empty():
		return
	var tree := Engine.get_main_loop() as SceneTree
	for obj in _current_stage_data().objectives:
		_progress[obj]=maxi(int(_progress.get(obj,0)),obj.initial_progress(tree))


func _all_done() -> bool:
	if data.stages.is_empty():
		return false
	for obj in _current_stage_data().objectives:
		if int(_progress.get(obj,0))<obj.required_count:
			return false
	return true
