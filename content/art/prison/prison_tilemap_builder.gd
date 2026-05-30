@tool
class_name PrisonTilemapBuilder
extends Node2D

const SOURCE_ID := 0
const TILE_FLOOR_STONE := Vector2i(0, 0)
const TILE_FLOOR_CRACK := Vector2i(1, 0)
const TILE_FLOOR_MOSS := Vector2i(2, 0)
const TILE_FLOOR_WOOD := Vector2i(3, 0)
const TILE_FLOOR_INfirmary := Vector2i(4, 0)
const TILE_FLOOR_YARD := Vector2i(5, 0)
const TILE_FLOOR_INTERROGATION := Vector2i(6, 0)
const TILE_FLOOR_SEWER := Vector2i(7, 0)

const TILE_WALL := Vector2i(0, 1)
const TILE_WALL_LEFT := Vector2i(1, 1)
const TILE_WALL_RIGHT := Vector2i(2, 1)
const TILE_WALL_BOTH := Vector2i(3, 1)
const TILE_WALL_TOP := Vector2i(4, 1)
const TILE_WALL_TOP_LEFT := Vector2i(5, 1)
const TILE_WALL_TOP_RIGHT := Vector2i(6, 1)
const TILE_WALL_TOP_BOTH := Vector2i(7, 1)

const TILE_BAR := Vector2i(0, 2)
const TILE_GATE := Vector2i(1, 2)
const TILE_DOOR := Vector2i(2, 2)
const TILE_TORCH := Vector2i(3, 2)
const TILE_DRAIN := Vector2i(4, 2)
const TILE_TRIM_H := Vector2i(5, 2)
const TILE_TRIM_V := Vector2i(6, 2)
const TILE_THRESHOLD := Vector2i(7, 2)

const TILE_PILLAR := Vector2i(0, 3)
const TILE_CRACK_DETAIL := Vector2i(1, 3)
const TILE_MOSS_DETAIL := Vector2i(2, 3)
const TILE_SHADOW := Vector2i(3, 3)
const TILE_CORNER_LEFT := Vector2i(4, 3)
const TILE_CORNER_RIGHT := Vector2i(5, 3)
const TILE_PLATE := Vector2i(6, 3)
const TILE_PLATE_ARROW := Vector2i(7, 3)

@export var ground_layer_path: NodePath = NodePath("GroundTiles")
@export var wall_layer_path: NodePath = NodePath("WallTiles")
@export var detail_layer_path: NodePath = NodePath("DetailTiles")
@export var floor_root: NodePath = NodePath("../PrisonFloor")
@export var wall_root: NodePath = NodePath("../PrisonWalls")
@export var gameplay_root: NodePath = NodePath("../PrisonGameplay")
@export var props_root: NodePath = NodePath("../PrisonProps")
@export var legacy_environment_root: NodePath = NodePath("")
@export_range(16, 32, 1) var tile_size: int = 32:
	set(value):
		tile_size = maxi(16, value)
		rebuild()

var _editor_accumulator: float = 0.0


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	rebuild()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_editor_accumulator += delta
	if _editor_accumulator >= 0.5:
		_editor_accumulator = 0.0
		rebuild()


func rebuild() -> void:
	var ground := get_node_or_null(ground_layer_path) as TileMapLayer
	var walls := get_node_or_null(wall_layer_path) as TileMapLayer
	var details := get_node_or_null(detail_layer_path) as TileMapLayer
	if ground == null or walls == null or details == null:
		return

	ground.clear()
	walls.clear()
	details.clear()
	_apply_scene_visibility()
	_build_ground(ground, details)
	_build_walls(walls, details)
	_build_scene_details(details)


func _apply_scene_visibility() -> void:
	var legacy_environment := get_node_or_null(legacy_environment_root)
	if legacy_environment != null:
		legacy_environment.visible = false

	var floor_node := get_node_or_null(floor_root)
	if floor_node != null:
		for child in floor_node.get_children():
			if child is ColorRect:
				child.visible = false

	var props_node := get_node_or_null(props_root)
	if props_node != null:
		for child in props_node.get_children():
			if child is Label:
				child.visible = false
			elif child is ColorRect:
				if child.name.begins_with("CellBar") or child.name.begins_with("Torch") or child.name.begins_with("TileSeam"):
					child.visible = false
			elif child is Sprite2D:
				if child.name.begins_with("PixelBars_") or child.name.begins_with("PixelTorch_"):
					child.visible = false


func _build_ground(ground: TileMapLayer, details: TileMapLayer) -> void:
	var floor_node := get_node_or_null(floor_root)
	if floor_node == null:
		return

	for child in floor_node.get_children():
		if child is ColorRect:
			var rect: Rect2 = _color_rect_to_rect(child)
			var base_tile: Vector2i = _ground_tile_for_name(child.name)
			_fill_tile_rect(ground, rect, base_tile)
			_stamp_room_detail_tiles(details, rect, child.name)


func _build_walls(walls: TileMapLayer, details: TileMapLayer) -> void:
	var walls_node := get_node_or_null(wall_root)
	if walls_node == null:
		return

	for child in walls_node.get_children():
		if not (child is CollisionShape2D and child.shape is RectangleShape2D):
			continue
		var rect: Rect2 = Rect2(child.position - child.shape.size * 0.5, child.shape.size)
		var horizontal: bool = rect.size.x >= rect.size.y
		if horizontal:
			var atlas: Vector2i = TILE_WALL_TOP if child.name.contains("North") else TILE_WALL
			_fill_tile_rect(walls, rect, atlas)
			_place_horizontal_caps(details, rect, child.name.contains("North"))
		else:
			var atlas_v: Vector2i = TILE_WALL_LEFT if child.name.contains("West") else TILE_WALL_RIGHT
			_fill_tile_rect(walls, rect, atlas_v)
			_place_vertical_caps(details, rect, child.name.contains("West"))

		if child.name.contains("Cracked") or child.name.contains("Sewer"):
			_stamp_sparse_detail(details, rect, TILE_CRACK_DETAIL)
		elif child.name.contains("Yard") or child.name.contains("Chapel"):
			_stamp_sparse_detail(details, rect, TILE_MOSS_DETAIL)


func _build_scene_details(details: TileMapLayer) -> void:
	var gameplay := get_node_or_null(gameplay_root)
	if gameplay != null:
		for child in gameplay.get_children():
			if child is Node2D:
				if child.name.contains("Door"):
					_place_single(details, child.position, TILE_DOOR)
					_place_single(details, child.position + Vector2(0, 32), TILE_THRESHOLD)
				elif child.name.contains("Gate"):
					_place_single(details, child.position, TILE_GATE)
					_place_single(details, child.position + Vector2(0, 32), TILE_THRESHOLD)
				elif child.name.contains("PressurePlate"):
					_place_single(details, child.position, TILE_PLATE_ARROW)

	var props := get_node_or_null(props_root)
	if props == null:
		return
	for child in props.get_children():
		if child is ColorRect:
			if child.name.begins_with("CellBar"):
				_fill_tile_rect(details, _color_rect_to_rect(child), TILE_BAR)
			elif child.name.begins_with("Torch"):
				_place_single(details, _rect_center(_color_rect_to_rect(child)), TILE_TORCH)
			elif child.name == "DrainGrate":
				_fill_tile_rect(details, _color_rect_to_rect(child), TILE_DRAIN)
			elif child.name == "BloodStain":
				_place_single(details, _rect_center(_color_rect_to_rect(child)), TILE_CRACK_DETAIL)
				_place_single(details, _rect_center(_color_rect_to_rect(child)) + Vector2(32, 0), TILE_SHADOW)


func _ground_tile_for_name(name: String) -> Vector2i:
	match name:
		"StoneBase":
			return TILE_FLOOR_STONE
		"MainCorridor", "CellWingFloor", "SolitaryWingFloor":
			return TILE_FLOOR_STONE
		"GuardOfficeFloor", "ArchiveFloor", "SmugglerCacheFloor", "MessHallFloor":
			return TILE_FLOOR_WOOD
		"ArmoryFloor", "ChapelFloor":
			return TILE_FLOOR_CRACK
		"InfirmaryFloor":
			return TILE_FLOOR_INfirmary
		"InterrogationFloor":
			return TILE_FLOOR_INTERROGATION
		"YardFloor":
			return TILE_FLOOR_YARD
		"SewerFloor", "ExitFloor":
			return TILE_FLOOR_SEWER
		_:
			return TILE_FLOOR_STONE


func _stamp_room_detail_tiles(details: TileMapLayer, rect: Rect2, room_name: String) -> void:
	if room_name == "MainCorridor":
		_stamp_line(details, rect.position + Vector2(0, rect.size.y * 0.5), rect.size.x, true, TILE_TRIM_H)
	elif room_name == "YardFloor":
		_stamp_sparse_detail(details, rect.grow(-32), TILE_MOSS_DETAIL)
	elif room_name == "SewerFloor":
		_stamp_sparse_detail(details, rect.grow(-32), TILE_SHADOW)
	elif room_name == "ArchiveFloor":
		_stamp_line(details, rect.position + Vector2(rect.size.x * 0.5, 0), rect.size.y, false, TILE_TRIM_V)
	elif room_name == "CellWingFloor":
		_stamp_sparse_detail(details, rect.grow(-32), TILE_CRACK_DETAIL)


func _fill_tile_rect(layer: TileMapLayer, rect: Rect2, atlas_coords: Vector2i) -> void:
	var start: Vector2i = _world_to_cell(rect.position)
	var end: Vector2i = _world_to_cell(rect.position + rect.size - Vector2.ONE)
	for y in range(start.y, end.y + 1):
		for x in range(start.x, end.x + 1):
			layer.set_cell(Vector2i(x, y), SOURCE_ID, atlas_coords)


func _place_horizontal_caps(details: TileMapLayer, rect: Rect2, top_cap: bool) -> void:
	var start: Vector2i = _world_to_cell(rect.position)
	var end: Vector2i = _world_to_cell(rect.position + rect.size - Vector2.ONE)
	var left_tile: Vector2i = TILE_CORNER_LEFT if top_cap else TILE_TRIM_H
	var right_tile: Vector2i = TILE_CORNER_RIGHT if top_cap else TILE_TRIM_H
	details.set_cell(Vector2i(start.x, start.y), SOURCE_ID, left_tile)
	details.set_cell(Vector2i(end.x, start.y), SOURCE_ID, right_tile)


func _place_vertical_caps(details: TileMapLayer, rect: Rect2, west: bool) -> void:
	var start: Vector2i = _world_to_cell(rect.position)
	var end: Vector2i = _world_to_cell(rect.position + rect.size - Vector2.ONE)
	var pillar_tile: Vector2i = TILE_PILLAR if west else TILE_TRIM_V
	details.set_cell(Vector2i(start.x, start.y), SOURCE_ID, pillar_tile)
	details.set_cell(Vector2i(start.x, end.y), SOURCE_ID, pillar_tile)


func _stamp_sparse_detail(layer: TileMapLayer, rect: Rect2, atlas_coords: Vector2i) -> void:
	var start: Vector2i = _world_to_cell(rect.position)
	var end: Vector2i = _world_to_cell(rect.position + rect.size - Vector2.ONE)
	for y in range(start.y, end.y + 1, 2):
		for x in range(start.x, end.x + 1, 3):
			var hash_value: int = abs(x * 71 + y * 29)
			if hash_value % 4 == 0:
				layer.set_cell(Vector2i(x, y), SOURCE_ID, atlas_coords)


func _stamp_line(layer: TileMapLayer, world_start: Vector2, length: float, horizontal: bool, atlas_coords: Vector2i) -> void:
	var start_cell: Vector2i = _world_to_cell(world_start)
	var count: int = maxi(1, int(ceil(length / float(tile_size))))
	for i in range(count):
		var coords: Vector2i = start_cell + (Vector2i(i, 0) if horizontal else Vector2i(0, i))
		layer.set_cell(coords, SOURCE_ID, atlas_coords)


func _place_single(layer: TileMapLayer, world_position: Vector2, atlas_coords: Vector2i) -> void:
	layer.set_cell(_world_to_cell(world_position), SOURCE_ID, atlas_coords)


func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / float(tile_size)), floori(world_position.y / float(tile_size)))


func _color_rect_to_rect(node: ColorRect) -> Rect2:
	return Rect2(
		Vector2(node.offset_left, node.offset_top),
		Vector2(node.offset_right - node.offset_left, node.offset_bottom - node.offset_top)
	)


func _rect_center(rect: Rect2) -> Vector2:
	return rect.position + rect.size * 0.5
