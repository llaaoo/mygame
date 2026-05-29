class_name DialogueBalloon
extends CanvasLayer

static var active: Node = null
static var just_closed_frame: int = -1

var _lines: Array[String] = []
var _index: int = 0
var _label: RichTextLabel
var _ignore_input_until_msec: int = 0


func _ready() -> void:
	add_to_group("dialogue_balloon")
	if active != null and is_instance_valid(active) and active != self:
		active.queue_free()
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


func show_text(lines: Array[String], npc_name: String = "") -> void:
	_lines = lines
	_index = 0
	_ignore_input_until_msec = Time.get_ticks_msec() + 120
	_setup_ui(npc_name)
	_show_current_line()


func advance() -> void:
	_show_current_line()


func _setup_ui(npc_name: String) -> void:
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.05, 0.05, 0.1, 0.92)
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.offset_top = -120
	bg.offset_bottom = 0
	add_child(bg)

	_label = RichTextLabel.new()
	_label.name = "Text"
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 20
	_label.offset_top = 10
	_label.offset_right = -20
	_label.offset_bottom = -30
	_label.fit_content = true
	_label.bbcode_enabled = true
	_label.add_theme_font_size_override("normal_font_size", 16)
	bg.add_child(_label)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "[E / click to continue]"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -20
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 11)
	bg.add_child(hint)


func _show_current_line() -> void:
	if _index >= _lines.size():
		just_closed_frame = Engine.get_process_frames()
		queue_free()
		return
	_label.text = _lines[_index]
	_index += 1


func _unhandled_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() < _ignore_input_until_msec:
		return
	if event is InputEventMouseButton and event.is_pressed():
		advance()
		get_viewport().set_input_as_handled()
