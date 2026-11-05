class_name SoulRemnant
extends Node2D
## Only real encounter deaths create these; all clocks obey simulation pause.
var _life := 60.0
var _deadline := -1.0
var remaining: float:
	get:
		return minf(_life, maxf(0, _deadline - _clock())) if _deadline >= 0 else _life
	set(value):
		_life = maxf(0, value)
		_deadline = _clock() + _life
var revision := 0
var spent := false
var _reserved := false
var _label: Label
var _pulse := 0.0

func _ready() -> void:
	_deadline = _clock() + _life
	add_to_group("soul_remnant")
	RuntimeRegistration.register_ticker(self)
	z_index = 8
	_label = Label.new()
	_label.position = Vector2(-75, -45)
	_label.size.x = 150
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	add_child(_label)
	_refresh()

func tick(delta: float) -> void:
	_life = maxf(0, _life - delta)
	_pulse += delta
	if remaining <= 0:
		revision += 1
		queue_free()
	_refresh()

func available(actor: Node2D, radius: float) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and not spent and not _reserved and remaining > 0 and global_position.distance_to(actor.global_position) <= radius

func reserve(expected: int) -> bool:
	if spent or _reserved or revision != expected or remaining <= 0 or is_queued_for_deletion():
		return false
	_reserved = true
	return true

func finish(commit: bool) -> void:
	_reserved = false
	if commit:
		spent = true
		revision += 1
		queue_free()

func _refresh() -> void:
	if _label:
		_label.text = "残魂 · %.0fs" % remaining
	queue_redraw()

static func nearest(actor: Node2D, radius: float) -> SoulRemnant:
	var result: SoulRemnant
	var best := radius + 1
	var world := CastContext.default_world(actor)
	for node in actor.get_tree().get_nodes_in_group("soul_remnant"):
		if node is SoulRemnant and world and world.is_ancestor_of(node) and node.available(actor, radius):
			var distance: float = node.global_position.distance_to(actor.global_position)
			if distance < best:
				best = distance
				result = node
	return result

func _draw() -> void:
	var wave := 0.75 + 0.25 * sin(_pulse * 3)
	draw_circle(Vector2.ZERO, 26, Color(0.3, 0.75, 1, 0.08 * wave))
	draw_circle(Vector2(0, -8 - sin(_pulse * 2) * 4), 7, Color(0.7, 0.9, 1, wave))
	draw_arc(Vector2.ZERO, 16, _pulse, _pulse + PI * 1.6, 24, Color(0.4, 0.8, 1, 0.7), 2)

func _clock() -> float:
	var runtime := GameRuntime.instance
	var simulation := runtime.get_simulation_runtime() if runtime else null
	return simulation.elapsed_time if simulation else 0.0
