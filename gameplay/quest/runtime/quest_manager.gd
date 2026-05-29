class_name QuestManager
extends Node

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_progress(quest_id: String, stage: int, progress: Array)

var _active_quests: Array[QuestRuntime] = []
var _completed_quests: Array[String] = []
var _quest_catalog: Dictionary = {}
var _quest_resource_paths: Dictionary = {}


func _ready() -> void:
	_subscribe_to_events()


func _subscribe_to_events() -> void:
	if not CombatEventBus.instance:
		await get_tree().process_frame
	if not CombatEventBus.instance:
		return
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_KILL, _on_event)
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_INTERACT, _on_event)


func start_quest(data: QuestData) -> bool:
	if data == null or data.quest_id.is_empty():
		return false
	_register_quest_data(data)
	if _completed_quests.has(data.quest_id):
		return false
	for q in _active_quests:
		if q.data.quest_id == data.quest_id:
			return false

	var runtime := QuestRuntime.new()
	runtime.data = data.duplicate(true) as QuestData
	runtime.start()
	_active_quests.append(runtime)
	quest_started.emit(runtime.data.quest_id)
	print("Quest started: %s" % runtime.data.title)
	return true


func _on_event(ev: CombatEvent) -> void:
	for i in range(_active_quests.size() - 1, -1, -1):
		var q := _active_quests[i]
		q.on_event(ev)
		quest_progress.emit(q.data.quest_id, q.current_stage, q.get_progress())

		if q.state == QuestRuntime.QuestState.COMPLETED:
			_completed_quests.append(q.data.quest_id)
			_apply_rewards(q.data)
			_active_quests.remove_at(i)
			quest_completed.emit(q.data.quest_id)
			print("Quest completed: %s" % q.data.title)


func get_active_quests() -> Array[QuestRuntime]:
	return _active_quests.duplicate()


func is_completed(quest_id: String) -> bool:
	return _completed_quests.has(quest_id)


func is_active(quest_id: String) -> bool:
	for q in _active_quests:
		if q.data.quest_id == quest_id:
			return true
	return false


func set_completed_quests(ids: Array[String]) -> void:
	_completed_quests = ids.duplicate()


func get_completed_quests() -> Array[String]:
	return _completed_quests.duplicate()


func get_active_quest_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q in _active_quests:
		result.append({
			"quest_id": q.data.quest_id,
			"resource_path": _quest_resource_paths.get(q.data.quest_id, q.data.resource_path),
			"stage": q.current_stage,
			"progress": q.get_all_progress(),
		})
	return result


func restore_active_quests(states: Array) -> void:
	_active_quests.clear()
	for entry in states:
		if not (entry is Dictionary):
			continue
		var data := _load_quest_data(entry)
		if data == null or _completed_quests.has(data.quest_id):
			continue
		var runtime := QuestRuntime.new()
		runtime.data = data.duplicate(true) as QuestData
		runtime.restore(int(entry.get("stage", 0)), entry.get("progress", []))
		_active_quests.append(runtime)
		quest_started.emit(runtime.data.quest_id)
		quest_progress.emit(runtime.data.quest_id, runtime.current_stage, runtime.get_progress())


func _register_quest_data(data: QuestData) -> void:
	if data != null and not data.quest_id.is_empty():
		_quest_catalog[data.quest_id] = data
		if not data.resource_path.is_empty():
			_quest_resource_paths[data.quest_id] = data.resource_path


func _load_quest_data(entry: Dictionary) -> QuestData:
	var path: String = entry.get("resource_path", "")
	if not path.is_empty():
		var loaded := load(path) as QuestData
		if loaded != null:
			_register_quest_data(loaded)
			return loaded
	var quest_id: String = entry.get("quest_id", "")
	return _quest_catalog.get(quest_id, null) as QuestData


func _apply_rewards(data: QuestData) -> void:
	if data.reward_experience <= 0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player:
		CombatExecutor.report_exp_bonus(player, data.reward_experience)
