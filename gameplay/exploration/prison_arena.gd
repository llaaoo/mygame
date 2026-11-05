class_name PrisonArena
extends RefCounted
const WALL_THICKNESS := 36.0
const PILLAR_TEXTURE := preload("res://content/art/prison/prison_sucai/29_stone_plaque.png")
const BARRICADE_TEXTURE := preload("res://content/art/prison/prison_sucai/15_wood_table_large.png")
const STACK_TEXTURE := preload("res://content/art/prison/prison_sucai/16_crate_large.png")
const WALL_TEXTURE := preload("res://content/art/prison/prison_sucai/10_cell_bars_wide.png")
var _room_root: Node2D
var _room_origin := Vector2.ZERO
func build(parent: Node2D, layout: RefCounted) -> void:
	_room_root = parent
	_build_floor(layout)
	_build_walls(layout.arena_size)
	for i in range(layout.obstacles.size()):
		_add_room_obstacle(layout.obstacles[i], i)

func _build_floor(layout: RefCounted) -> void:
	var base_color := Color(0.10, 0.11, 0.13, 1.0)
	var accent := Color(0.25, 0.29, 0.33, 1.0)
	match layout.room_type:
		"barracks":
			base_color = Color(0.12, 0.12, 0.15, 1.0)
			accent = Color(0.29, 0.25, 0.20, 1.0)
		"traps":
			base_color = Color(0.08, 0.10, 0.10, 1.0)
			accent = Color(0.18, 0.34, 0.32, 1.0)
		"explosive":
			base_color = Color(0.13, 0.10, 0.08, 1.0)
			accent = Color(0.36, 0.20, 0.12, 1.0)
		"elite":
			base_color = Color(0.11, 0.075, 0.13, 1.0)
			accent = Color(0.48, 0.22, 0.48, 1.0)
		"boss":
			base_color = Color(0.12, 0.07, 0.06, 1.0)
			accent = Color(0.48, 0.15, 0.08, 1.0)

	var floor := _rect_poly(_room_origin, layout.arena_size, base_color)
	floor.name = "Floor"
	floor.z_index = -120
	_room_root.add_child(floor)

	for patch_data in layout.floor_patches:
		var patch_position: Vector2 = patch_data.get("position", Vector2.ZERO)
		var patch_size: Vector2 = patch_data.get("size", Vector2(48, 32))
		var tone: float = patch_data.get("tone", 0.1)
		var patch := _rect_poly(_room_origin + patch_position, patch_size, base_color.lerp(accent, tone))
		patch.z_index = -118
		_room_root.add_child(patch)

	var detail := preload("res://gameplay/presentation/prison_floor_detail.gd").new()
	detail.extent = layout.arena_size
	detail.base = base_color
	detail.accent = accent
	detail.z_index = -116
	_room_root.add_child(detail)


func _build_walls(arena_size: Vector2) -> void:
	var half := arena_size * 0.5
	_add_wall("NorthWall", _room_origin + Vector2(0, -half.y - WALL_THICKNESS * 0.5), Vector2(arena_size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall("SouthWall", _room_origin + Vector2(0, half.y + WALL_THICKNESS * 0.5), Vector2(arena_size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS))
	_add_wall("WestWall", _room_origin + Vector2(-half.x - WALL_THICKNESS * 0.5, 0), Vector2(WALL_THICKNESS, arena_size.y))
	_add_wall("EastWall", _room_origin + Vector2(half.x + WALL_THICKNESS * 0.5, 0), Vector2(WALL_THICKNESS, arena_size.y))


func _add_wall(name_str: String, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = name_str
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	_room_root.add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	var visual := _rect_poly(Vector2.ZERO, size, Color(0.05, 0.055, 0.065, 1.0))
	visual.z_index = -80
	body.add_child(visual)


func _add_room_obstacle(spec: Dictionary, index: int) -> void:
	var position_offset: Vector2 = spec.get("position", Vector2.ZERO)
	var obstacle_size: Vector2 = spec.get("size", Vector2(64, 64))
	var kind := str(spec.get("kind", "wall"))
	var body := StaticBody2D.new()
	body.name = "RoomObstacle_%02d_%s" % [index + 1, kind]
	body.collision_layer = 1
	body.collision_mask = 0
	body.global_position = _room_origin + position_offset
	_room_root.add_child(body)

	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = obstacle_size
	collision.shape = rect
	body.add_child(collision)

	var colors := {
		"pillar": Color(0.16, 0.17, 0.19, 1.0),
		"barricade": Color(0.20, 0.16, 0.12, 1.0),
		"stack": Color(0.18, 0.14, 0.10, 1.0),
		"wall": Color(0.12, 0.13, 0.15, 1.0),
	}
	var obstacle_color: Color = colors.get(kind, colors.wall)
	var shadow := _rect_poly(Vector2(5, 7), obstacle_size + Vector2(8, 8), Color(0.01, 0.012, 0.016, 0.48))
	shadow.z_index = -42
	body.add_child(shadow)
	var visual := _rect_poly(Vector2.ZERO, obstacle_size, obstacle_color)
	visual.z_index = -40
	body.add_child(visual)
	var cap := _rect_poly(Vector2(0, -obstacle_size.y * 0.34), Vector2(obstacle_size.x - 8, maxf(6.0, obstacle_size.y * 0.18)), obstacle_color.lightened(0.16))
	cap.z_index = -39
	body.add_child(cap)

	var texture_by_kind := {
		"pillar": PILLAR_TEXTURE,
		"barricade": BARRICADE_TEXTURE,
		"stack": STACK_TEXTURE,
		"wall": WALL_TEXTURE,
	}
	var texture := texture_by_kind.get(kind) as Texture2D
	if texture:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var texture_size := texture.get_size()
		sprite.scale = Vector2(
			(obstacle_size.x + 16.0) / texture_size.x,
			(obstacle_size.y + 18.0) / texture_size.y
		)
		sprite.position.y = -5.0
		sprite.z_index = -37
		body.add_child(sprite)


func _rect_poly(center: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var half := size * 0.5
	poly.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(-half.x, half.y),
	])
	poly.color = color
	return poly
