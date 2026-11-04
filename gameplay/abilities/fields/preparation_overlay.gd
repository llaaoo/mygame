extends Node2D
## Reads active statuses; the indicator owns no gameplay state.
var _elapsed := 0.0
var _echo := false
var _guard := false
var _label: Label

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
	_echo = buffs.has_buff("echo_ready")
	_guard = buffs.has_buff("resonant_guard")
	_label.text = ""
	for entry in buffs.get_active_buff_entries():
		if entry.status_id in ["echo_ready", "resonant_guard"]:
			_label.text += "%s %.0fs " % ["回响" if entry.status_id == "echo_ready" else "护盾", entry.remaining]
	queue_redraw()

func _draw() -> void:
	if _guard:
		draw_circle(Vector2.ZERO, 38, Color(0.3, 0.8, 1, 0.13))
		draw_arc(Vector2.ZERO, 38, 0, TAU, 40, Color(0.3, 0.8, 1, 0.9), 2)
	if _echo:
		for i in range(6):
			var angle := i * TAU / 6.0
			draw_arc(Vector2.ZERO, 30, angle, angle + 0.6, 8, Color(0.4, 1, 0.8, 0.85), 2)
