extends SceneTree

const SAMPLE_SEEDS := [17, 101, 2027, 99173, 440021]
const NORMAL_ROOM_COUNT := 4
const ROOM_GENERATOR_SCRIPT := preload("res://gameplay/rooms/run_room_generator.gd")
var _failures: Array[String] = []


func _init() -> void:
	var generator = ROOM_GENERATOR_SCRIPT.new()
	var observed_templates: Dictionary = {}
	for seed in SAMPLE_SEEDS:
		var first: Array = generator.generate_run(seed, NORMAL_ROOM_COUNT)
		var second: Array = generator.generate_run(seed, NORMAL_ROOM_COUNT)
		_check(first.size() == NORMAL_ROOM_COUNT, "run plan has wrong room count")
		_check(_plan_signature(first) == _plan_signature(second), "seed %d is not deterministic" % seed)
		_check(first.back().room_type == "elite", "seed %d does not end normal route with elite room" % seed)
		var early_types: Array[String] = []
		for index in range(first.size() - 1):
			early_types.append(first[index].room_type)
		_check(early_types.has("barracks") and early_types.has("traps") and early_types.has("explosive"), "seed %d lost an early room archetype" % seed)
		for layout in first:
			observed_templates[layout.template_id] = true
			_validate_layout(layout)

	var seed_a: Array = generator.generate_run(1234, NORMAL_ROOM_COUNT)
	var seed_b: Array = generator.generate_run(5678, NORMAL_ROOM_COUNT)
	_check(_plan_signature(seed_a) != _plan_signature(seed_b), "different seeds generated identical plans")
	_check(observed_templates.size() >= 5, "template weighting did not expose enough room variants")

	for seed in range(40, 60):
		for layout in generator.generate_run(seed, NORMAL_ROOM_COUNT):
			_validate_layout(layout)
		_validate_layout(generator.generate_room(seed, NORMAL_ROOM_COUNT, "boss"))

	if _failures.is_empty():
		print("Room generation tests passed: %d templates sampled" % observed_templates.size())
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _validate_layout(layout: RefCounted) -> void:
	_check(layout.contains_offset(layout.entry_offset, 24.0), "%s entry leaves arena" % layout.template_id)
	_check(layout.contains_offset(layout.exit_offset, 24.0), "%s exit leaves arena" % layout.template_id)
	_check(layout.entry_offset.distance_to(layout.exit_offset) > layout.arena_size.x * 0.65, "%s route is too short" % layout.template_id)
	for obstacle in layout.obstacles:
		var point: Vector2 = obstacle.get("position", Vector2.ZERO)
		var size: Vector2 = obstacle.get("size", Vector2.ZERO)
		_check(layout.contains_offset(point, maxf(size.x, size.y) * 0.5 + 20.0), "%s obstacle leaves arena" % layout.template_id)
	for prop in layout.props:
		var point: Vector2 = prop.get("position", Vector2.ZERO)
		_check(layout.is_point_clear(point, float(prop.get("radius", 34.0))), "%s prop blocks a reserved area" % layout.template_id)
	for point in layout.enemy_offsets:
		_check(layout.is_point_clear(point, 42.0), "%s enemy spawned inside geometry" % layout.template_id)
	_check(_has_grid_path(layout), "%s has no entry-to-exit route" % layout.template_id)


func _has_grid_path(layout: RefCounted) -> bool:
	const CELL := 40.0
	var half: Vector2 = layout.arena_size * 0.5
	var min_cell := Vector2i(ceili(-half.x / CELL), ceili(-half.y / CELL))
	var max_cell := Vector2i(floori(half.x / CELL), floori(half.y / CELL))
	var start := Vector2i(roundi(layout.entry_offset.x / CELL), roundi(layout.entry_offset.y / CELL))
	var goal := Vector2i(roundi(layout.exit_offset.x / CELL), roundi(layout.exit_offset.y / CELL))
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			return true
		for direction in directions:
			var next: Vector2i = cell + direction
			if visited.has(next) or next.x < min_cell.x or next.y < min_cell.y or next.x > max_cell.x or next.y > max_cell.y:
				continue
			var point := Vector2(next) * CELL
			if _blocked_by_obstacle(layout, point, 24.0):
				continue
			visited[next] = true
			queue.append(next)
	return false


func _blocked_by_obstacle(layout: RefCounted, point: Vector2, radius: float) -> bool:
	for obstacle in layout.obstacles:
		var size: Vector2 = obstacle.get("size", Vector2.ZERO)
		var center: Vector2 = obstacle.get("position", Vector2.ZERO)
		if Rect2(center - size * 0.5, size).grow(radius).has_point(point):
			return true
	return false


func _plan_signature(layouts: Array) -> String:
	var signatures: Array[String] = []
	for layout in layouts:
		signatures.append(layout.signature())
	return "\n".join(signatures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
