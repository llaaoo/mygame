extends Node2D
## Shows the actual simulation cells rather than a separate visual-only state.
const COLORS := {"wet": Color(0.2, 0.5, 0.9, 0.32), "frozen": Color(0.45, 0.9, 1, 0.42), "oiled": Color(0.45, 0.3, 0.1, 0.5), "burning": Color(1, 0.28, 0.05, 0.5), "electrified": Color(0.8, 0.55, 1, 0.5), "steam": Color(0.8, 0.85, 0.9, 0.4), "poisoned": Color(0.4, 0.8, 0.15, 0.45)}
var _elapsed := 0.0

func _ready() -> void:
	z_index = -100

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.15:
		_elapsed = 0
		queue_redraw()

func _draw() -> void:
	if not GameRuntime.instance:
		return
	var simulation := GameRuntime.instance.get_simulation_runtime()
	for cell: Vector2i in simulation.surface_cells():
		var state: String = simulation.surface_at(cell).state
		if not COLORS.has(state):
			continue
		var point := to_local(Vector2(cell.x * 64, cell.y * 64))
		var rect := Rect2(point + Vector2.ONE * 2, Vector2.ONE * 60)
		draw_rect(rect, COLORS[state])
		draw_rect(rect, Color(COLORS[state], 0.65), false, 1)
		if state == "electrified":
			draw_polyline(PackedVector2Array([point + Vector2(38, 9), point + Vector2(24, 31), point + Vector2(40, 31), point + Vector2(26, 54)]), Color(1, 0.9, 1), 2)
