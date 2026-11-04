class_name FireSigil
extends Node2D
## A spatial preparation condition; never deals damage on its own.

var field_type := "fire"
var caster: Node2D
var radius := 96.0
var remaining := 15.0
var charges := 2
var revision := 0
var _label: Label
var _consumed: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	RuntimeRegistration.register_ticker(self)
	add_to_group("conditional_field")
	_label = Label.new()
	var offset: float = {"fire": 0.0, "frost": 18.0, "storm": 36.0}.get(field_type, 0.0)
	_label.position = Vector2(-100, -radius - 25 - offset)
	_label.size.x = 200
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	add_child(_label)
	_update_label()
	queue_redraw()

func tick(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0 or charges <= 0 or not is_instance_valid(caster):
		expire()
		return
	_update_label()

func is_available_to(actor: Node2D) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and remaining > 0 and charges > 0 and actor == caster and global_position.distance_to(actor.global_position) <= radius

func consume(actor: Node2D, expected_revision: int, execution_id: int) -> bool:
	if not is_available_to(actor) or revision != expected_revision or _consumed.has(execution_id):
		return false
	_consumed[execution_id] = true
	charges -= 1
	revision += 1
	_update_label()
	return true

func refund_consumption(execution_id: int) -> void:
	if _consumed.erase(execution_id) and not is_queued_for_deletion():
		charges += 1
		revision += 1
		_update_label()

func expire() -> void:
	remaining = 0.0
	revision += 1
	queue_free()

func _update_label() -> void:
	_label.text = "%s · %d 次 · %.0fs" % [title_for(field_type), charges, remaining]

static func title_for(type: String) -> String:
	return {"fire": "火阵", "frost": "霜阵", "storm": "雷阵"}.get(type, type)

func _draw() -> void:
	var tint := Color(0.35, 0.75, 1.0) if field_type == "frost" else Color(1.0, 0.38, 0.08)
	if field_type == "storm":
		tint = Color(0.85, 0.65, 1.0)
	var ring_radius := radius - (4.0 if field_type == "frost" else (8.0 if field_type == "storm" else 0.0))
	draw_circle(Vector2.ZERO, radius, Color(tint, 0.09))
	draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 64, Color(tint, 0.9), 3, true)
	draw_arc(Vector2.ZERO, radius * 0.78, 0, TAU, 64, Color(tint, 0.65), 1, true)
	for i in range(6):
		var angle := i * TAU / 6.0
		draw_line(Vector2.from_angle(angle) * radius * 0.55, Vector2.from_angle(angle + TAU / 3) * radius * 0.55, Color(tint, 0.6), 2, true)
