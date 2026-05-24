class_name DialogueNPC
extends Node2D
## 对话 NPC — 按 E 对话 + Schedule 驱动日常行为
##
## 配置优先级:
##   1. dialogue_resource — .dialogue 文件（编辑器创建）
##   2. dialogue — NPCDialogue .tres（旧格式，运行时转换为 DialogueResource）


@export var dialogue_resource: Resource = null       ## .dialogue 文件
@export var dialogue: NPCDialogue = null             ## 旧格式兼容
@export var schedule: NPCSchedule = null             ## 日程表（为 null 则原地不动）


func _ready() -> void:
	add_to_group("interactable")
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.set_callback(_on_talk)
	add_child(interactable)

	# 日程 Brain + Markers（全部延迟到树稳定后）
	call_deferred("_setup_npc_schedule")


var _tick_count: int = 0

func _process(delta: float) -> void:
	_tick_count += 1
	if _tick_count == 1:
		print("🟢 %s._process 开始, schedule=%s, pos=%s" % [name, "有" if schedule else "无", position])
	# Tick Brain + MoveToTask
	var brain := get_node_or_null("NPCBrain") as NPCBrain
	if brain:
		brain.tick(delta)
	var task := get_node_or_null("MoveToTask") as MoveToTask
	if task:
		task.tick(delta)


func _on_talk(_actor: Node2D) -> void:
	if dialogue and not dialogue.lines.is_empty():
		_show_balloon(dialogue.lines, dialogue.npc_name)
	elif dialogue_resource:
		_show_from_dialogue_resource()
	else:
		_show_balloon(["..."], "")


func _show_balloon(lines: Array[String], npc_name: String) -> void:
	var balloon := DialogueBalloon.new()
	balloon.name = "DialogueBalloon"
	get_tree().current_scene.add_child(balloon)
	balloon.show_text(lines, npc_name)


func _show_from_dialogue_resource() -> void:
	var dm := _get_dialogue_manager()
	if not dm or not dialogue_resource:
		return
	dm.show_example_dialogue_balloon(dialogue_resource)


var _dm_cache: Node = null


func _get_dialogue_manager() -> Node:
	if _dm_cache:
		return _dm_cache
	if Engine.has_singleton("DialogueManager"):
		_dm_cache = Engine.get_singleton("DialogueManager")
		return _dm_cache
	_dm_cache = load("res://addons/dialogue_manager/dialogue_manager.gd").new()
	_dm_cache.name = "DialogueManager"
	get_tree().current_scene.add_child(_dm_cache)
	return _dm_cache


func _setup_npc_schedule() -> void:
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
	if MarkerRegistry.has("forge") and MarkerRegistry.has("bed"):
		print("📍 markers 已存在")
		return
	print("📍 创建测试 markers: forge + bed")

	var parent := get_parent()
	if not parent:
		return

	# Forge marker — 玩家出生点右侧
	var forge := WorldMarker.new()
	forge.name = "ForgeMarker"
	forge.marker_id = "forge"
	parent.add_child(forge)
	forge.position = Vector2(400, -419)
	MarkerRegistry.register(forge)
	print("📍 forge global_pos=%s" % str(forge.global_position))

	# Bed marker — 左侧 NPC 附近
	var bed := WorldMarker.new()
	bed.name = "BedMarker"
	bed.marker_id = "bed"
	parent.add_child(bed)
	bed.position = Vector2(-550, -400)
	MarkerRegistry.register(bed)
	print("📍 bed global_pos=%s" % str(bed.global_position))


func _resolve_dialogue_resource() -> Resource:
	if dialogue_resource:
		return dialogue_resource
	return null
