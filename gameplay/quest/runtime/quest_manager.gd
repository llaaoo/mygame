class_name QuestManager
extends Node
## 任务管理器 — 极小职责：激活任务、转发事件、追踪进度
##
## 不认识任务类型。不控制世界。


signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_progress(quest_id: String, stage: int, progress: Array)


var _active_quests: Array[QuestRuntime] = []
var _completed_quests: Array[String] = []


func _ready() -> void:
	# 订阅事件总线（任务需要的所有事件类型）
	_subscribe_to_events()


func _subscribe_to_events() -> void:
	if not CombatEventBus.instance:
		await get_tree().process_frame
	if not CombatEventBus.instance:
		return
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_KILL, _on_event)
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_INTERACT, _on_event)


func start_quest(data: QuestData) -> bool:
	if _completed_quests.has(data.quest_id):
		return false
	for q in _active_quests:
		if q.data.quest_id == data.quest_id:
			return false  # 已激活

	var runtime := QuestRuntime.new()
	runtime.data = data
	runtime.start()
	_active_quests.append(runtime)
	quest_started.emit(data.quest_id)
	print("📋 任务开始: %s" % data.title)
	return true


func _on_event(ev: CombatEvent) -> void:
	# 不认识事件类型，只转发
	for i in range(_active_quests.size() - 1, -1, -1):
		var q := _active_quests[i]
		q.on_event(ev)
		var stage := q.current_stage
		quest_progress.emit(q.data.quest_id, stage, q.get_progress())

		if q.state == QuestRuntime.QuestState.COMPLETED:
			_completed_quests.append(q.data.quest_id)
			_active_quests.remove_at(i)
			quest_completed.emit(q.data.quest_id)
			print("✅ 任务完成: %s" % q.data.title)


func get_active_quests() -> Array[QuestRuntime]:
	return _active_quests.duplicate()


func is_completed(quest_id: String) -> bool:
	return _completed_quests.has(quest_id)


## 设置已完成任务列表（供 SaveManager 恢复）
func set_completed_quests(ids: Array[String]) -> void:
	_completed_quests = ids.duplicate()


## 获取已完成任务列表（供 SaveManager 序列化）
func get_completed_quests() -> Array[String]:
	return _completed_quests.duplicate()
