extends Node2D
## Every visible tile is an actual simulation cell. Shared edges are suppressed.
var _elapsed := 0.0
var _phase := 0.0
func _ready() -> void: z_index = -100
func _process(delta: float) -> void:
	_phase += delta
	_elapsed += delta
	if _elapsed >= .1:
		_elapsed = 0
		queue_redraw()
func _draw() -> void:
	if not GameRuntime.instance: return
	var simulation := GameRuntime.instance.get_simulation_runtime()
	for cell: Vector2i in simulation.surface_cells():
		var medium: Dictionary = simulation.surface_at(cell)
		var state: String = medium.state
		if state == "dry" or not SurfaceCatalog.definition(state): continue
		var point := to_local(Vector2(cell * 64))
		var color := Color(SurfaceCatalog.color_for(state), 1)
		var fade := clampf(float(medium.remaining) / 1.5, .15, 1)
		draw_rect(Rect2(point, Vector2(64, 64)), Color(color, .16 * fade))
		var neighbors := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		var corners := [Vector2(0, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)]
		for i in range(4):
			if simulation.surface_at(cell + neighbors[i]).state != state:
				draw_line(point + corners[i], point + corners[(i + 1) % 4], Color(color, .4 * fade), 1, true)
		var seed_phase := float(posmod(cell.x * 7 + cell.y * 13, 19))
		var phase := _phase + seed_phase
		match state:
			"wet", "electrified":
				for i in range(2):
					var center := point + Vector2(18 + i * 25, 26 + i * 15)
					draw_arc(center, 9 + fmod(phase * 7 + i * 6, 12), .2, PI - .2, 12, Color(color.lightened(.3), .35 * fade), 1, true)
				if state == "electrified":
					var shift := sin(phase * 9) * 3
					draw_polyline(PackedVector2Array([point + Vector2(39, 8), point + Vector2(23 + shift, 28), point + Vector2(37, 31), point + Vector2(24, 55)]), Color(color.lightened(.45), (.65 + .25 * sin(phase * 8)) * fade), 2, true)
			"frozen":
				draw_colored_polygon(PackedVector2Array([point + Vector2(9, 15), point + Vector2(47, 5), point + Vector2(57, 43), point + Vector2(22, 58)]), Color(color, .12 * fade))
				draw_polyline(PackedVector2Array([point + Vector2(8, 9), point + Vector2(30, 26), point + Vector2(21, 46), point + Vector2(35, 58)]), Color(color.lightened(.3), .55 * fade), 1, true)
				draw_line(point + Vector2(30, 26), point + Vector2(53, 19), Color(color, .55 * fade), 1, true)
			"burning":
				for i in range(5):
					var origin := point + Vector2(8 + i * 12, 40 + sin(i * 4.0) * 13)
					var height := 12 + 9 * (.5 + .5 * sin(phase * 6 + i))
					draw_colored_polygon(PackedVector2Array([origin + Vector2(-5, 8), origin + Vector2(sin(phase * 4 + i) * 4, -height), origin + Vector2(5, 5)]), Color(color, .65 * fade))
					draw_circle(origin, 2, Color(1, .8, .3, .8 * fade))
			"poisoned":
				for i in range(4):
					var center := point + Vector2(12 + i * 13, 16 + posmod(i * 17, 36))
					var bubble := 3 + fmod(phase * 2 + i, 5)
					draw_circle(center, bubble, Color(color, .2 * fade))
					draw_arc(center, bubble, PI, TAU, 12, Color(color.lightened(.3), .6 * fade), 1, true)
			"steam":
				for i in range(3):
					draw_circle(point + Vector2(15 + i * 17, 35 + sin(phase * 1.5 + i) * 12), 11, Color(color, .12 * fade))
			"oiled":
				draw_circle(point + Vector2(32, 32), 23, Color(.04, .035, .025, .6 * fade))
				draw_arc(point + Vector2(32, 32), 19, PI * 1.1, PI * 1.6, 16, Color(color.lightened(.3), .5 * fade), 2, true)
