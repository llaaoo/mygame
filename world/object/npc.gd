class_name NPC
extends Node2D
## NPC — 按 E 对话，使用 Dialogue Manager 插件显示气泡
##
## 配置优先级:
##   1. dialogue_resource — .dialogue 文件（编辑器创建）
##   2. dialogue — NPCDialogue .tres（旧格式，运行时转换为 DialogueResource）


@export var dialogue_resource: Resource = null       ## .dialogue 文件
@export var dialogue: NPCDialogue = null             ## 旧格式兼容


func _ready() -> void:
	add_to_group("interactable")
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.set_callback(_on_talk)
	add_child(interactable)


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


func _resolve_dialogue_resource() -> Resource:
	if dialogue_resource:
		return dialogue_resource
	return null
