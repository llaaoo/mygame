class_name DialogueBalloon
extends CanvasLayer

static var active: Node = null
static var just_closed_frame: int = -1

var _lines: Array[String] = []
var _index: int = 0
var _label: RichTextLabel
var _ignore_input_until_msec: int = 0


func _ready() -> void:
	layer = GameUIStyle.LAYER_CRITICAL
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
	var dim := ColorRect.new()
	dim.name = "DialogueDim"
	dim.color = Color(0, 0, 0, 0.18)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var bg := PanelContainer.new()
	bg.name = "BG"
	bg.anchor_left = 0.12
	bg.anchor_right = 0.88
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_top = -154
	bg.offset_bottom = -18
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.98, 6, GameUIStyle.BORDER_STRONG))
	add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(box)
	if not npc_name.is_empty():
		var speaker := Label.new()
		speaker.text = npc_name
		speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		GameUIStyle.apply_label(speaker, 13, GameUIStyle.GOLD)
		box.add_child(speaker)

	_label = RichTextLabel.new()
	_label.name = "Text"
	_label.custom_minimum_size = Vector2(0, 68)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.fit_content = true
	_label.bbcode_enabled = true
	_label.add_theme_font_size_override("normal_font_size", 15)
	_label.add_theme_color_override("default_color", GameUIStyle.TEXT_MAIN)
	box.add_child(_label)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "继续  ›"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_label(hint, 11, GameUIStyle.TEXT_MUTED)
	box.add_child(hint)


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
