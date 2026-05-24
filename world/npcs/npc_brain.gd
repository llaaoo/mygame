class_name NPCBrain
extends Node
## NPC 大脑 — P1 极简：只读 Schedule
##
## 后续 P2/P3 才加 Needs/Memory/Relationship


var schedule: NPCSchedule
var current_entry: ScheduleEntry = null
var _npc: Node2D


func setup(npc: Node2D, sched: NPCSchedule) -> void:
	_npc = npc
	schedule = sched


func tick(_delta: float) -> void:
	if not WorldTime.instance:
		return
	var hour := WorldTime.instance.get_hour()
	var entry := schedule.get_entry_for_hour(hour)
	if entry == current_entry:
		return
	current_entry = entry
	print("🧠 %s: %02d:00 → %s" % [_npc.name, int(hour), entry.action_type if entry else "null"])
	_execute_entry(entry)


## 将日程条目转换为通用 Action（统一 Player/NPC/Enemy 的意图表达）
func make_action(entry: ScheduleEntry) -> Action:
	if not entry:
		return Action.idle()
	match entry.action_type:
		"move":
			return Action.move(MarkerRegistry.get_position(entry.target_marker) - _npc.global_position, _npc)
		"idle":
			return Action.idle()
		"wander":
			return Action.idle()  # P2 实现
	return Action.idle()


func _execute_entry(entry: ScheduleEntry) -> void:
	if not entry:
		return
	# 产生通用 Action（与 Player._poll_universal_actions 输出相同类型）
	var action := make_action(entry)
	match action.action_type:
		Action.ActionType.MOVE:
			_start_move(entry.target_marker)
		Action.ActionType.IDLE:
			pass  # P1: 原地不动
		_:
			pass  # P2 实现其他类型


func _start_move(marker_id: String) -> void:
	if marker_id.is_empty():
		return
	var agent := _npc.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if not agent:
		return

	# 复用已有 MoveToTask，避免重名冲突
	var task := _npc.get_node_or_null("MoveToTask") as MoveToTask
	if task:
		task.target_marker = marker_id
		task._target_pos = MarkerRegistry.get_position(marker_id)
		task._started = false
	else:
		task = MoveToTask.new()
		task.name = "MoveToTask"
		task.setup(_npc, agent, marker_id)
		_npc.add_child(task)
	print("🚶 %s → %s" % [_npc.name, marker_id])
