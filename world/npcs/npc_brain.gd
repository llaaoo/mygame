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


func _execute_entry(entry: ScheduleEntry) -> void:
	if not entry:
		return
	match entry.action_type:
		"move":
			_start_move(entry.target_marker)
		"idle":
			pass  # P1: 原地不动
		"wander":
			pass  # P2 实现


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
