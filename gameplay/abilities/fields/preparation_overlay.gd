extends Node2D
## Reads active statuses; the indicator owns no gameplay state.
var _elapsed := 0.0
var _echo := false
var _guard := false
var _souls := 0
var _soul_limit := 3
var _label: Label
var _attunement: Dictionary = {}

func _ready() -> void:
	z_index = 3
	_label = Label.new()
	_label.position = Vector2(-75, -62)
	_label.size.x = 150
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	add_child(_label)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.1:
		return
	_elapsed = 0
	var buffs := get_parent().get_node("BuffManager") as BuffManager
	_attunement = {}
	for entry in buffs.get_active_buff_entries():
		if entry.status_id in ["ember_focus", "frost_stride", "static_focus", "flow_attunement", "venom_accord"]:
			_attunement = entry
	_souls = buffs.get_stack_count("soul_charge")
	for entry in buffs.get_active_buff_entries():
		if entry.status_id == "soul_charge":
			_soul_limit = entry.capacity
	_echo = buffs.has_buff("echo_ready")
	_guard = buffs.has_buff("resonant_guard")
	_label.text = ""
	for entry in buffs.get_active_buff_entries():
		if entry.status_id.begins_with("stored_"):
			_label.text += "%s %d/3 %.0fs " % [entry.name,entry.stacks,entry.remaining]
		if entry.status_id in ["echo_ready", "resonant_guard"]:
			_label.text += "%s %.0fs " % ["回响" if entry.status_id == "echo_ready" else "护盾", entry.remaining]
	if _souls > 0:
		_label.text += "蕴魂%d/%d" % [_souls, _soul_limit]
	queue_redraw()

func _draw() -> void:
	if not _attunement.is_empty():
		var tint := ElementVisuals.status_color(_attunement.status_id)
		draw_set_transform(Vector2(0, 21), 0, Vector2(1, .42))
		draw_circle(Vector2.ZERO, 29, Color(tint, .06))
		draw_arc(Vector2.ZERO, 29, 0, TAU, 40, Color(tint, .25), 1, true)
		draw_arc(Vector2.ZERO, 29, -PI / 2, -PI / 2 + TAU * maxf(.001, _attunement.progress), 40, Color(tint, .85), 2, true)
		draw_set_transform(Vector2.ZERO)
	for i in range(_souls):
		var point := Vector2.from_angle(-PI / 2 + (i - (_souls - 1) * 0.5) * 0.35) * 44
		draw_circle(point, 3, Color(0.7, 0.8, 1))
	if _guard:
		draw_circle(Vector2.ZERO, 38, Color(0.3, 0.8, 1, 0.13))
		draw_arc(Vector2.ZERO, 38, 0, TAU, 40, Color(0.3, 0.8, 1, 0.9), 2)
	if _echo:
		for i in range(6):
			var angle := i * TAU / 6.0
			draw_arc(Vector2.ZERO, 30, angle, angle + 0.6, 8, Color(0.4, 1, 0.8, 0.85), 2)
