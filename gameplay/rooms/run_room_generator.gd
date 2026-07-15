class_name RunRoomGenerator
extends RefCounted

const TEMPLATE_PATHS: Array[String] = [
	"res://content/rooms/prison_yard.tres",
	"res://content/rooms/guard_crossroads.tres",
	"res://content/rooms/cell_gauntlet.tres",
	"res://content/rooms/powder_magazine.tres",
	"res://content/rooms/execution_ring.tres",
	"res://content/rooms/molten_sanctum.tres",
]
const ROOM_TEMPLATE_SCRIPT := preload("res://gameplay/rooms/run_room_template.gd")
const ROOM_LAYOUT_SCRIPT := preload("res://gameplay/rooms/run_room_layout.gd")

var _templates: Array[Resource] = []


func _init() -> void:
	for path in TEMPLATE_PATHS:
		var template := load(path) as Resource
		if template:
			_templates.append(template)


func generate_run(run_seed: int, room_count: int) -> Array:
	var layouts: Array = []
	if room_count <= 0:
		return layouts
	var rng := _make_rng(run_seed)
	var early_types: Array[String] = ["barracks", "traps", "explosive"]
	_shuffle(early_types, rng)
	for index in range(room_count):
		var room_type := "elite" if index == room_count - 1 else early_types[index % early_types.size()]
		layouts.append(generate_room(run_seed, index, room_type))
	return layouts


func generate_room(run_seed: int, room_index: int, room_type: String) -> RefCounted:
	var room_seed := _mix_seed(run_seed, room_index, room_type)
	var rng := _make_rng(room_seed)
	var template := _pick_template(room_type, rng)
	var layout := ROOM_LAYOUT_SCRIPT.new()
	layout.seed = room_seed
	layout.room_index = room_index
	layout.room_type = room_type
	layout.template_id = template.template_id if template else "fallback"
	layout.display_name = template.display_name if template else "临时牢区"
	layout.pattern = template.pattern if template else "open"
	layout.arena_size = template.arena_size if template else Vector2(1120, 720)
	layout.mirrored_x = rng.randf() < 0.5
	layout.mirrored_y = rng.randf() < 0.5

	var half: Vector2 = layout.arena_size * 0.5
	var lane_y := float(rng.randi_range(-1, 1)) * 72.0
	layout.entry_offset = Vector2(-half.x + 108.0, lane_y)
	layout.exit_offset = Vector2(half.x - 56.0, -lane_y)
	layout.boss_offset = Vector2(half.x * 0.22, 0)
	layout.obstacles = _build_obstacles(layout.pattern, layout.mirrored_x, layout.mirrored_y)
	layout.floor_patches = _build_floor_patches(layout, rng)

	var prop_budget: int = template.prop_budget if template else 2
	var hazard_budget: int = template.hazard_budget if template else 1
	layout.props = _build_props(layout, prop_budget, hazard_budget, rng)
	var enemy_count: int = 2 if room_type == "elite" else 3 + room_index
	if room_type == "boss":
		enemy_count = 0
	layout.enemy_offsets = _build_enemy_offsets(layout, enemy_count, rng)
	return layout


func _pick_template(room_type: String, rng: RandomNumberGenerator) -> Resource:
	var candidates: Array[Resource] = []
	var total_weight := 0.0
	for template in _templates:
		if template.supports(room_type):
			candidates.append(template)
			total_weight += template.weight
	if candidates.is_empty():
		return null
	var roll := rng.randf() * total_weight
	for template in candidates:
		roll -= template.weight
		if roll <= 0.0:
			return template
	return candidates.back()


func _build_obstacles(pattern: String, mirror_x: bool, mirror_y: bool) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	match pattern:
		"pillars":
			for p in [Vector2(-190, -165), Vector2(-190, 165), Vector2(190, -165), Vector2(190, 165)]:
				specs.append(_obstacle(p, Vector2(68, 104), "pillar"))
		"crossroads":
			specs.append(_obstacle(Vector2(-130, -145), Vector2(210, 52), "barricade"))
			specs.append(_obstacle(Vector2(130, 145), Vector2(210, 52), "barricade"))
			specs.append(_obstacle(Vector2(0, -245), Vector2(64, 84), "pillar"))
			specs.append(_obstacle(Vector2(0, 245), Vector2(64, 84), "pillar"))
		"split":
			specs.append(_obstacle(Vector2(50, -190), Vector2(58, 220), "wall"))
			specs.append(_obstacle(Vector2(50, 190), Vector2(58, 220), "wall"))
			specs.append(_obstacle(Vector2(-250, 0), Vector2(90, 90), "stack"))
		"gauntlet":
			for i in range(4):
				var y := -205.0 if i % 2 == 0 else 205.0
				specs.append(_obstacle(Vector2(-270 + i * 180, y), Vector2(230, 54), "barricade"))
		"ring":
			specs.append(_obstacle(Vector2(0, -215), Vector2(230, 54), "barricade"))
			specs.append(_obstacle(Vector2(0, 215), Vector2(230, 54), "barricade"))
			specs.append(_obstacle(Vector2(-245, 0), Vector2(54, 150), "pillar"))
			specs.append(_obstacle(Vector2(245, 0), Vector2(54, 150), "pillar"))
		"sanctum":
			for p in [Vector2(-230, -210), Vector2(-230, 210), Vector2(230, -210), Vector2(230, 210)]:
				specs.append(_obstacle(p, Vector2(82, 118), "pillar"))
	for spec in specs:
		var p: Vector2 = spec.position
		if mirror_x:
			p.x *= -1.0
		if mirror_y:
			p.y *= -1.0
		spec.position = p
	return specs


func _build_props(layout: RefCounted, prop_budget: int, hazard_budget: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for i in range(prop_budget):
		var kind := "barrel" if layout.room_type == "explosive" and i % 2 == 0 else "crate"
		if layout.room_type in ["elite", "boss"] and i == 0:
			kind = "barrel"
		_try_add_prop(specs, layout, kind, rng)
	for i in range(hazard_budget):
		var kind := "trap" if layout.room_type in ["traps", "elite", "boss"] else "barrel"
		_try_add_prop(specs, layout, kind, rng)
	if layout.room_type != "boss":
		_try_add_prop(specs, layout, "chest", rng, 44.0)
	return specs


func _try_add_prop(specs: Array[Dictionary], layout: RefCounted, kind: String, rng: RandomNumberGenerator, radius: float = 34.0) -> void:
	for attempt in range(48):
		var half: Vector2 = layout.arena_size * 0.5
		var point: Vector2 = Vector2(
			rng.randf_range(-half.x + 155.0, half.x - 150.0),
			rng.randf_range(-half.y + 105.0, half.y - 105.0)
		).round()
		if not layout.is_point_clear(point, radius):
			continue
		var overlaps := false
		for existing in specs:
			var other: Vector2 = existing.get("position", Vector2.ZERO)
			if point.distance_to(other) < radius + float(existing.get("radius", 34.0)) + 24.0:
				overlaps = true
				break
		if overlaps:
			continue
		specs.append({"kind": kind, "position": point, "radius": radius})
		return


func _build_enemy_offsets(layout: RefCounted, count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in range(count):
		var placed := false
		for attempt in range(64):
			var half: Vector2 = layout.arena_size * 0.5
			var point: Vector2 = Vector2(
				rng.randf_range(-40.0, half.x - 155.0),
				rng.randf_range(-half.y + 110.0, half.y - 110.0)
			).round()
			if not layout.is_point_clear(point, 42.0) or point.distance_to(layout.entry_offset) < 300.0:
				continue
			var blocked := false
			for prop in layout.props:
				if point.distance_to(prop.get("position", Vector2.ZERO)) < 92.0:
					blocked = true
					break
			for other in points:
				if point.distance_to(other) < 105.0:
					blocked = true
					break
			if blocked:
				continue
			points.append(point)
			placed = true
			break
		if not placed:
			var fallback := _find_enemy_fallback(layout, points)
			if fallback != Vector2.INF:
				points.append(fallback)
	return points


func _find_enemy_fallback(layout: RefCounted, occupied: Array[Vector2]) -> Vector2:
	var half: Vector2 = layout.arena_size * 0.5
	for y in range(int(-half.y + 100.0), int(half.y - 100.0), 72):
		for x in range(0, int(half.x - 130.0), 72):
			var point := Vector2(x, y)
			if not layout.is_point_clear(point, 42.0) or point.distance_to(layout.entry_offset) < 280.0:
				continue
			var blocked := false
			for prop in layout.props:
				if point.distance_to(prop.get("position", Vector2.ZERO)) < 92.0:
					blocked = true
					break
			for other in occupied:
				if point.distance_to(other) < 96.0:
					blocked = true
					break
			if not blocked:
				return point
	return Vector2.INF


func _build_floor_patches(layout: RefCounted, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var patches: Array[Dictionary] = []
	var half: Vector2 = layout.arena_size * 0.5
	for i in range(14):
		patches.append({
			"position": Vector2(rng.randf_range(-half.x + 40, half.x - 40), rng.randf_range(-half.y + 40, half.y - 40)).round(),
			"size": Vector2(rng.randi_range(28, 76), rng.randi_range(18, 52)),
			"tone": rng.randf_range(0.06, 0.16),
		})
	return patches


func _obstacle(position: Vector2, size: Vector2, kind: String) -> Dictionary:
	return {"position": position, "size": size, "kind": kind}


func _make_rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _mix_seed(run_seed: int, room_index: int, room_type: String) -> int:
	return abs(hash("%d:%d:%s" % [run_seed, room_index, room_type])) + 1


func _shuffle(values: Array[String], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var value := values[i]
		values[i] = values[other]
		values[other] = value
