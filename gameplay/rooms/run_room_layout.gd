class_name RunRoomLayout
extends RefCounted

var seed: int = 0
var room_index: int = 0
var room_type: String = "barracks"
var template_id: String = "room"
var display_name: String = "未知区域"
var pattern: String = "open"
var arena_size: Vector2 = Vector2(1120, 720)
var entry_offset: Vector2 = Vector2(-450, 0)
var exit_offset: Vector2 = Vector2(500, 0)
var boss_offset: Vector2 = Vector2(260, 0)
var mirrored_x: bool = false
var mirrored_y: bool = false
var obstacles: Array[Dictionary] = []
var props: Array[Dictionary] = []
var enemy_offsets: Array[Vector2] = []
var floor_patches: Array[Dictionary] = []


func contains_offset(point: Vector2, margin: float = 0.0) -> bool:
	var half := arena_size * 0.5 - Vector2.ONE * margin
	return absf(point.x) <= half.x and absf(point.y) <= half.y


func is_point_clear(point: Vector2, radius: float = 24.0) -> bool:
	if not contains_offset(point, radius + 24.0):
		return false
	if point.distance_to(entry_offset) < radius + 130.0:
		return false
	if point.distance_to(exit_offset) < radius + 120.0:
		return false
	for obstacle in obstacles:
		var obstacle_size: Vector2 = obstacle.get("size", Vector2.ZERO)
		var obstacle_position: Vector2 = obstacle.get("position", Vector2.ZERO)
		var rect := Rect2(obstacle_position - obstacle_size * 0.5, obstacle_size).grow(radius)
		if rect.has_point(point):
			return false
	return true


func signature() -> String:
	var parts: Array[String] = [
		str(seed), room_type, template_id, pattern,
		"%d,%d" % [int(arena_size.x), int(arena_size.y)],
		"%d,%d" % [int(entry_offset.x), int(entry_offset.y)],
		"%d,%d" % [int(exit_offset.x), int(exit_offset.y)],
	]
	for obstacle in obstacles:
		var p: Vector2 = obstacle.get("position", Vector2.ZERO)
		var s: Vector2 = obstacle.get("size", Vector2.ZERO)
		parts.append("o:%d,%d:%d,%d" % [int(p.x), int(p.y), int(s.x), int(s.y)])
	for prop in props:
		var p: Vector2 = prop.get("position", Vector2.ZERO)
		parts.append("p:%s:%d,%d" % [str(prop.get("kind", "")), int(p.x), int(p.y)])
	for p in enemy_offsets:
		parts.append("e:%d,%d" % [int(p.x), int(p.y)])
	return "|".join(parts)
