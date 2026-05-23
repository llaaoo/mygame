class_name NPC
extends Node2D
## NPC — 按 E 对话，头顶显示气泡文字
##
## 配置: dialogue 指向 NPCDialogue .tres


@export var dialogue: NPCDialogue

var _label: Label = null
var _bubble: ColorRect = null
var _line_index: int = 0


func _ready() -> void:
	add_to_group("interactable")
	# Interactable 接口
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.set_callback(_on_talk)
	add_child(interactable)
	# 气泡 UI
	_setup_bubble()


func _setup_bubble() -> void:
	_bubble = ColorRect.new()
	_bubble.name = "SpeechBubble"
	_bubble.color = Color(0, 0, 0, 0.8)
	_bubble.size = Vector2(200, 60)
	_bubble.position = Vector2(-100, -80)
	_bubble.visible = false
	add_child(_bubble)

	_label = Label.new()
	_label.name = "Text"
	_label.size = Vector2(190, 50)
	_label.position = Vector2(5, 5)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", 12)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_label)


func _on_talk(_actor: Node2D) -> void:
	if not dialogue or dialogue.lines.is_empty():
		_show_text("...")
		return
	_show_text(dialogue.lines[_line_index])
	_line_index = (_line_index + 1) % dialogue.lines.size()


func _show_text(text: String) -> void:
	if not _label or not _bubble:
		return
	_label.text = text
	_bubble.visible = true
	# 3 秒后自动隐藏
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func(): _bubble.visible = false)
