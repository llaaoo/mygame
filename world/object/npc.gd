class_name DialogueNPC
extends Node2D

@export var dialogue_resource: Resource = null
@export var dialogue: NPCDialogue = null
@export var schedule: NPCSchedule = null
@export var enable_schedule: bool = true
@export var quest_data: QuestData = null
@export var quest_available_lines: Array[String] = []
@export var quest_active_lines: Array[String] = []
@export var quest_completed_lines: Array[String] = []

var _tick_count: int = 0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("villager")
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.set_callback(_on_talk)
	add_child(interactable)

	process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_setup_npc_schedule")
	RuntimeRegistration.register_ticker(self)


func tick(delta: float) -> void:
	_tick_count += 1
	var brain := get_node_or_null("NPCBrain") as NPCBrain
	if brain:
		brain.tick(delta)
	var task := get_node_or_null("MoveToTask") as MoveToTask
	if task:
		task.tick(delta)


func _on_talk(actor: Node2D) -> void:
	if _try_handle_quest(actor):
		return
	if dialogue and not dialogue.lines.is_empty():
		_show_balloon(dialogue.lines, dialogue.npc_name)
	elif dialogue_resource:
		_show_from_dialogue_resource()
	else:
		_show_balloon(["..."], "")


func _try_handle_quest(actor: Node2D) -> bool:
	if quest_data == null:
		return false
	var qm := _get_quest_manager(actor)
	if qm == null:
		return false
	if qm.is_completed(quest_data.quest_id):
		_show_balloon(_lines_or_default(quest_completed_lines, ["You have done enough for now."]), _npc_display_name())
		return true
	if qm.is_active(quest_data.quest_id):
		_show_balloon(_lines_or_default(quest_active_lines, ["Finish the work, then come back."]), _npc_display_name())
		return true
	var started := qm.start_quest(quest_data)
	if started:
		_show_balloon(_lines_or_default(quest_available_lines, ["Trouble is close. Clear it out and report back."]), _npc_display_name())
	return started


func _get_quest_manager(actor: Node2D) -> QuestManager:
	if actor:
		var qm := actor.get("quest_manager") as QuestManager
		if qm != null:
			return qm
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.get("quest_manager") as QuestManager
	return null


func _lines_or_default(lines: Array[String], fallback: Array[String]) -> Array[String]:
	return lines if not lines.is_empty() else fallback


func _npc_display_name() -> String:
	if dialogue:
		return dialogue.npc_name
	return name


func _show_balloon(lines: Array[String], npc_name: String) -> void:
	var balloon := DialogueBalloon.new()
	balloon.name = "DialogueBalloon"
	balloon.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(balloon)
	balloon.show_text(lines, npc_name)


func _show_from_dialogue_resource() -> void:
	var resource := dialogue_resource as DialogueResource
	var manager := Engine.get_singleton("DialogueManager") if Engine.has_singleton("DialogueManager") else null
	if manager and resource:
		manager.show_example_dialogue_balloon(resource)


func _setup_npc_schedule() -> void:
	if not enable_schedule:
		return
	if not schedule:
		schedule = _create_default_schedule()
	_create_test_markers()
	if schedule:
		_setup_npc_brain()


func _setup_npc_brain() -> void:
	var agent := NavigationAgent2D.new()
	agent.name = "NavigationAgent2D"
	add_child(agent)

	var brain := NPCBrain.new()
	brain.name = "NPCBrain"
	add_child(brain)
	brain.setup(self, schedule)


func _create_default_schedule() -> NPCSchedule:
	var sched := NPCSchedule.new()

	var entry1 := ScheduleEntry.new()
	entry1.start_hour = 6
	entry1.end_hour = 18
	entry1.action_type = "move"
	entry1.target_marker = "forge"
	sched.entries.append(entry1)

	var entry2 := ScheduleEntry.new()
	entry2.start_hour = 18
	entry2.end_hour = 22
	entry2.action_type = "idle"
	entry2.target_marker = "forge"
	sched.entries.append(entry2)

	var entry3 := ScheduleEntry.new()
	entry3.start_hour = 22
	entry3.end_hour = 6
	entry3.action_type = "move"
	entry3.target_marker = "bed"
	sched.entries.append(entry3)

	return sched


func _create_test_markers() -> void:
	var scope := WorldScope.resolve(self)
	var parent := get_parent()
	if not scope or not parent:
		return
	if not MarkerRegistry.find_marker("forge", scope):
		var forge := WorldMarker.new()
		forge.name = "ForgeMarker"
		forge.marker_id = "forge"
		forge.position = Vector2(400, -419)
		parent.add_child(forge)
	if not MarkerRegistry.find_marker("bed", scope):
		var bed := WorldMarker.new()
		bed.name = "BedMarker"
		bed.marker_id = "bed"
		bed.position = Vector2(-550, -400)
		parent.add_child(bed)


func _resolve_dialogue_resource() -> Resource:
	if dialogue_resource:
		return dialogue_resource
	return null
