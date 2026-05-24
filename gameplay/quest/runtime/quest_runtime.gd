class_name QuestRuntime
extends RefCounted
## 任务运行时 — 持有 QuestData（只读）+ 追踪当前阶段和进度


enum QuestState { NOT_STARTED, ACTIVE, COMPLETED, FAILED }

var data: QuestData
var state: QuestState = QuestState.NOT_STARTED
var current_stage: int = 0


func start() -> void:
	state = QuestState.ACTIVE
	current_stage = 0
	_reset_all_objectives()


func _reset_all_objectives() -> void:
	for stage in data.stages:
		for obj in stage.objectives:
			obj.reset()


func _current_stage_data() -> QuestStageData:
	return data.stages[current_stage]


## 事件入口 — QuestManager 调用
func on_event(ev: CombatEvent) -> void:
	if state != QuestState.ACTIVE:
		return

	# 1. 当前阶段的目标：总是响应
	for obj in _current_stage_data().objectives:
		_try_progress(obj, ev)

	# 2. 后续阶段的目标：仅 track_from_start=true 的提前累计
	for s_idx in range(current_stage + 1, data.stages.size()):
		for obj in data.stages[s_idx].objectives:
			if obj.track_from_start:
				_try_progress(obj, ev)

	while _all_done():
		if current_stage < data.stages.size() - 1:
			current_stage += 1
		else:
			state = QuestState.COMPLETED
			break


func _try_progress(obj: QuestObjective, ev: CombatEvent) -> void:
	if obj.is_completed():
		return
	obj.on_event(ev)  # 子类内部自行 current += 1


func _all_done() -> bool:
	for obj in _current_stage_data().objectives:
		if not obj.is_completed():
			return false
	return true


## 获取当前阶段进度（供 UI 用）
func get_progress() -> Array[int]:
	var result: Array[int] = []
	for obj in _current_stage_data().objectives:
		result.append(obj.current)
	return result
