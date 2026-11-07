class_name FireSigil
extends Node2D
## A spatial preparation condition; never deals damage on its own.

var field_type := "fire"
var caster: Node2D
var radius := 96.0
var remaining := 15.0
var charges := 2
var revision := 0
var use_seconds := 0.0
var initial_duration := 15.0
func configure_budget(duration: float,per_use: float) -> void:
	remaining=duration; initial_duration=duration; use_seconds=per_use
	charges=ceili(remaining/use_seconds) if use_seconds>0 else charges
func consumption_text() -> String:
	return "剩余存续-%.0f秒"%use_seconds if use_seconds>0 else "1次充能"
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
	if use_seconds>0: charges=ceili(remaining/use_seconds)
	if remaining <= 0.0 or charges <= 0 or not is_instance_valid(caster):
		expire()
		return
	_update_label()

func is_available_to(actor: Node2D) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and remaining > 0 and charges > 0 and actor == caster and global_position.distance_to(actor.global_position) <= radius

func consume(actor: Node2D, expected_revision: int, execution_id: int) -> bool:
	if not is_available_to(actor) or revision != expected_revision or _consumed.has(execution_id):
		return false
	_consumed[execution_id] = minf(use_seconds,remaining) if use_seconds>0 else 0.0
	if use_seconds>0:
		remaining=maxf(0,remaining-use_seconds)
		charges=ceili(remaining/use_seconds)
	else: charges -= 1
	revision += 1
	_update_label()
	return true

func refund_consumption(execution_id: int) -> void:
	if _consumed.has(execution_id) and not is_queued_for_deletion():
		var restored: float=_consumed[execution_id]
		_consumed.erase(execution_id)
		if use_seconds>0:
			remaining+=restored
			charges=ceili(remaining/use_seconds)
		else: charges += 1
		revision += 1
		_update_label()

func expire() -> void:
	remaining = 0.0
	revision += 1
	queue_free()

func _update_label() -> void:
	if not is_instance_valid(_label): return
	_label.text = ("%s · %.0f秒 · 每次-%.0f秒"%[title_for(field_type),remaining,use_seconds]) if use_seconds>0 else "%s · %d 次 · %.0fs" % [title_for(field_type), charges, remaining]

static func title_for(type: String) -> String:
	return {"arcane": "凝能阵", "fire": "火阵", "frost": "霜阵", "storm": "雷阵", "ward":"守护阵"}.get(type, type)

func _draw() -> void:
	var tag: String = {"fire": "fire", "frost": "ice", "storm": "lightning"}.get(field_type, "arcane")
	var tint := ElementVisuals.color_for([tag])
	var ring_radius := radius - (4.0 if field_type == "frost" else 8.0 if field_type == "storm" else 0.0)
	draw_circle(Vector2.ZERO, ring_radius, Color(tint, .045))
	draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 80, Color(tint, .7), 1.5, true)
	draw_arc(Vector2.ZERO, ring_radius - 6, 0, TAU, 80, Color(tint, .3), 1, true)
	for i in range(12):
		var angle := i * TAU / 12
		var outer := Vector2.from_angle(angle) * ring_radius
		var inner := Vector2.from_angle(angle) * (ring_radius - (11 if i % 3 == 0 else 5))
		draw_line(inner, outer, Color(tint, .7), 1.5, true)
	for i in range(6):
		var angle := i * TAU / 6 - PI / 2
		draw_line(Vector2.from_angle(angle) * radius * .53, Vector2.from_angle(angle + TAU / 3) * radius * .53, Color(tint, .55), 1, true)
	for i in range(mini(charges,8)):
		var angle := -PI / 2 + (i - (charges - 1) * .5) * .22
		draw_circle(Vector2.from_angle(angle) * (ring_radius - 15), 3, tint.lightened(.3))
	draw_arc(Vector2.ZERO, ring_radius - 3, -PI / 2, -PI / 2 + TAU * clampf(remaining / initial_duration, 0, 1), 64, Color(tint, .32), 2, true)
