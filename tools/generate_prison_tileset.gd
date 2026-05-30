extends SceneTree

const OUTPUT_IMAGE_PATH := "res://content/art/prison/prison_tileset_runtime.png"
const OUTPUT_TILESET_PATH := "res://content/art/prison/prison_tileset_runtime.tres"
const TILE_SIZE := 32
const SHEET_COLUMNS := 8
const SHEET_ROWS := 4


func _init() -> void:
	var image: Image = Image.create(TILE_SIZE * SHEET_COLUMNS, TILE_SIZE * SHEET_ROWS, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	_draw_floor_tile(image, Vector2i(0, 0), Color(0.31, 0.31, 0.33), false, false)
	_draw_floor_tile(image, Vector2i(1, 0), Color(0.30, 0.30, 0.32), true, false)
	_draw_floor_tile(image, Vector2i(2, 0), Color(0.30, 0.31, 0.29), false, true)
	_draw_floor_tile(image, Vector2i(3, 0), Color(0.34, 0.28, 0.22), true, false)
	_draw_floor_tile(image, Vector2i(4, 0), Color(0.23, 0.30, 0.30), false, true)
	_draw_floor_tile(image, Vector2i(5, 0), Color(0.21, 0.26, 0.22), false, true)
	_draw_floor_tile(image, Vector2i(6, 0), Color(0.24, 0.20, 0.17), true, false)
	_draw_floor_tile(image, Vector2i(7, 0), Color(0.18, 0.22, 0.23), false, true)

	_draw_wall_tile(image, Vector2i(0, 1), false, false)
	_draw_wall_tile(image, Vector2i(1, 1), true, false)
	_draw_wall_tile(image, Vector2i(2, 1), false, true)
	_draw_wall_tile(image, Vector2i(3, 1), true, true)
	_draw_wall_tile(image, Vector2i(4, 1), false, false, true)
	_draw_wall_tile(image, Vector2i(5, 1), true, false, true)
	_draw_wall_tile(image, Vector2i(6, 1), false, true, true)
	_draw_wall_tile(image, Vector2i(7, 1), true, true, true)

	_draw_bar_tile(image, Vector2i(0, 2))
	_draw_gate_tile(image, Vector2i(1, 2))
	_draw_door_tile(image, Vector2i(2, 2))
	_draw_torch_tile(image, Vector2i(3, 2))
	_draw_grate_tile(image, Vector2i(4, 2))
	_draw_trim_tile(image, Vector2i(5, 2))
	_draw_trim_tile(image, Vector2i(6, 2), true)
	_draw_threshold_tile(image, Vector2i(7, 2))

	_draw_pillar_tile(image, Vector2i(0, 3))
	_draw_crack_tile(image, Vector2i(1, 3))
	_draw_moss_tile(image, Vector2i(2, 3))
	_draw_shadow_tile(image, Vector2i(3, 3))
	_draw_corner_cap_tile(image, Vector2i(4, 3))
	_draw_corner_cap_tile(image, Vector2i(5, 3), true)
	_draw_plate_tile(image, Vector2i(6, 3))
	_draw_plate_tile(image, Vector2i(7, 3), true)

	var image_error: int = image.save_png(ProjectSettings.globalize_path(OUTPUT_IMAGE_PATH))
	if image_error != OK:
		push_error("Failed to save image: %s" % image_error)
		quit(1)
		return

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for y in range(SHEET_ROWS):
		for x in range(SHEET_COLUMNS):
			atlas.create_tile(Vector2i(x, y))

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(atlas, 0)
	var save_error: int = ResourceSaver.save(tile_set, OUTPUT_TILESET_PATH)
	if save_error != OK:
		push_error("Failed to save tileset: %s" % save_error)
		quit(1)
		return

	print("Generated prison tileset: %s and %s" % [OUTPUT_IMAGE_PATH, OUTPUT_TILESET_PATH])
	quit()


func _draw_floor_tile(image: Image, tile: Vector2i, base_color: Color, cracked: bool, mossy: bool) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), base_color.darkened(0.18))
	for y in range(0, TILE_SIZE, 8):
		for x in range(0, TILE_SIZE, 8):
			var cell := Rect2i(origin + Vector2i(x, y), Vector2i(8, 8))
			var v := _noise(cell.position.x, cell.position.y, tile.x + tile.y * 11)
			var tint := base_color.darkened(0.04 + v * 0.1)
			if v > 0.7:
				tint = tint.lightened(0.08)
			_fill_rect(image, cell, tint)
			_fill_rect(image, Rect2i(cell.position, Vector2i(cell.size.x, 1)), tint.lightened(0.08))
			_fill_rect(image, Rect2i(cell.position + Vector2i(0, cell.size.y - 1), Vector2i(cell.size.x, 1)), tint.darkened(0.18))
			_fill_rect(image, Rect2i(cell.position, Vector2i(1, cell.size.y)), tint.lightened(0.06))
			_fill_rect(image, Rect2i(cell.position + Vector2i(cell.size.x - 1, 0), Vector2i(1, cell.size.y)), tint.darkened(0.14))
	if cracked:
		for point in [Vector2i(6, 12), Vector2i(11, 16), Vector2i(15, 18), Vector2i(19, 22), Vector2i(25, 26)]:
			_fill_rect(image, Rect2i(origin + point, Vector2i(3, 1)), base_color.darkened(0.45))
	if mossy:
		for point in [Vector2i(4, 5), Vector2i(18, 8), Vector2i(7, 21), Vector2i(22, 24)]:
			_fill_rect(image, Rect2i(origin + point, Vector2i(5, 3)), Color(0.24, 0.34, 0.18))


func _draw_wall_tile(image: Image, tile: Vector2i, left_cap: bool, right_cap: bool, top_cap: bool = false) -> void:
	var origin := tile * TILE_SIZE
	var stone := Color(0.43, 0.44, 0.47)
	var dark := Color(0.20, 0.21, 0.24)
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), dark)
	_fill_rect(image, Rect2i(origin + Vector2i(0, 12), Vector2i(TILE_SIZE, TILE_SIZE - 12)), dark.darkened(0.1))
	if top_cap:
		_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, 12)), stone.lightened(0.05))
		_draw_brick_row(image, origin + Vector2i(0, 0), 12, stone)
	_draw_brick_row(image, origin + Vector2i(0, 12), 10, stone.darkened(0.05))
	_draw_brick_row(image, origin + Vector2i(0, 22), 10, stone.darkened(0.12))
	if left_cap:
		_fill_rect(image, Rect2i(origin + Vector2i(0, 0), Vector2i(8, TILE_SIZE)), stone.darkened(0.06))
	if right_cap:
		_fill_rect(image, Rect2i(origin + Vector2i(TILE_SIZE - 8, 0), Vector2i(8, TILE_SIZE)), stone.darkened(0.1))


func _draw_bar_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0, 0, 0, 0))
	for x in [6, 12, 18, 24]:
		_fill_rect(image, Rect2i(origin + Vector2i(x, 3), Vector2i(3, 26)), Color(0.35, 0.36, 0.4))
	_fill_rect(image, Rect2i(origin + Vector2i(3, 5), Vector2i(26, 3)), Color(0.24, 0.25, 0.28))
	_fill_rect(image, Rect2i(origin + Vector2i(3, 24), Vector2i(26, 3)), Color(0.19, 0.2, 0.22))


func _draw_gate_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0.08, 0.08, 0.09))
	for x in [7, 13, 19]:
		_fill_rect(image, Rect2i(origin + Vector2i(x, 4), Vector2i(3, 24)), Color(0.36, 0.37, 0.4))
	_fill_rect(image, Rect2i(origin + Vector2i(4, 4), Vector2i(24, 3)), Color(0.25, 0.25, 0.28))
	_fill_rect(image, Rect2i(origin + Vector2i(4, 25), Vector2i(24, 3)), Color(0.21, 0.21, 0.24))
	_fill_rect(image, Rect2i(origin + Vector2i(22, 12), Vector2i(6, 8)), Color(0.43, 0.34, 0.16))


func _draw_door_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	var wood := Color(0.30, 0.19, 0.1)
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0.10, 0.10, 0.11))
	_fill_rect(image, Rect2i(origin + Vector2i(4, 3), Vector2i(24, 26)), wood.darkened(0.12))
	_fill_rect(image, Rect2i(origin + Vector2i(7, 7), Vector2i(18, 18)), wood)
	for y in [10, 16, 22]:
		_fill_rect(image, Rect2i(origin + Vector2i(7, y), Vector2i(18, 1)), wood.lightened(0.08))
	_fill_rect(image, Rect2i(origin + Vector2i(21, 15), Vector2i(3, 3)), Color(0.62, 0.58, 0.44))


func _draw_torch_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0, 0, 0, 0))
	_fill_rect(image, Rect2i(origin + Vector2i(14, 12), Vector2i(4, 14)), Color(0.28, 0.17, 0.08))
	_fill_rect(image, Rect2i(origin + Vector2i(10, 6), Vector2i(12, 10)), Color(0.90, 0.44, 0.08))
	_fill_rect(image, Rect2i(origin + Vector2i(12, 2), Vector2i(8, 8)), Color(1.0, 0.82, 0.28))


func _draw_grate_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0.14, 0.15, 0.16))
	_fill_rect(image, Rect2i(origin + Vector2i(4, 4), Vector2i(24, 24)), Color(0.22, 0.23, 0.25))
	for x in [9, 14, 19]:
		_fill_rect(image, Rect2i(origin + Vector2i(x, 7), Vector2i(2, 18)), Color(0.12, 0.13, 0.14))
	for y in [9, 14, 19]:
		_fill_rect(image, Rect2i(origin + Vector2i(7, y), Vector2i(18, 2)), Color(0.12, 0.13, 0.14))


func _draw_trim_tile(image: Image, tile: Vector2i, vertical: bool = false) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0.17, 0.18, 0.2))
	if vertical:
		_fill_rect(image, Rect2i(origin + Vector2i(12, 0), Vector2i(8, TILE_SIZE)), Color(0.34, 0.35, 0.38))
		_fill_rect(image, Rect2i(origin + Vector2i(14, 0), Vector2i(2, TILE_SIZE)), Color(0.45, 0.46, 0.5))
	else:
		_fill_rect(image, Rect2i(origin + Vector2i(0, 12), Vector2i(TILE_SIZE, 8)), Color(0.34, 0.35, 0.38))
		_fill_rect(image, Rect2i(origin + Vector2i(0, 14), Vector2i(TILE_SIZE, 2)), Color(0.45, 0.46, 0.5))


func _draw_threshold_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0.18, 0.18, 0.19))
	_fill_rect(image, Rect2i(origin + Vector2i(0, 18), Vector2i(TILE_SIZE, 8)), Color(0.42, 0.33, 0.18))
	_fill_rect(image, Rect2i(origin + Vector2i(0, 12), Vector2i(TILE_SIZE, 2)), Color(0.32, 0.32, 0.34))


func _draw_pillar_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0.13, 0.14, 0.16))
	_fill_rect(image, Rect2i(origin + Vector2i(8, 0), Vector2i(16, TILE_SIZE)), Color(0.38, 0.39, 0.42))
	_fill_rect(image, Rect2i(origin + Vector2i(10, 0), Vector2i(4, TILE_SIZE)), Color(0.46, 0.47, 0.5))


func _draw_crack_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_draw_floor_tile(image, tile, Color(0.31, 0.31, 0.33), true, false)
	for point in [Vector2i(4, 7), Vector2i(12, 10), Vector2i(18, 14), Vector2i(23, 20)]:
		_fill_rect(image, Rect2i(origin + point, Vector2i(2, 5)), Color(0.12, 0.12, 0.13))


func _draw_moss_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_draw_floor_tile(image, tile, Color(0.24, 0.30, 0.24), false, true)
	for point in [Vector2i(5, 11), Vector2i(18, 6), Vector2i(16, 23)]:
		_fill_rect(image, Rect2i(origin + point, Vector2i(7, 4)), Color(0.32, 0.45, 0.22))


func _draw_shadow_tile(image: Image, tile: Vector2i) -> void:
	var origin := tile * TILE_SIZE
	_draw_floor_tile(image, tile, Color(0.18, 0.19, 0.2), false, false)
	_fill_rect(image, Rect2i(origin + Vector2i(0, 0), Vector2i(TILE_SIZE, TILE_SIZE)), Color(0, 0, 0, 0.15))


func _draw_corner_cap_tile(image: Image, tile: Vector2i, flipped: bool = false) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), Color(0.10, 0.10, 0.11))
	_fill_rect(image, Rect2i(origin + Vector2i(0, 0), Vector2i(TILE_SIZE, 10)), Color(0.40, 0.41, 0.44))
	_fill_rect(image, Rect2i(origin + Vector2i((0 if not flipped else TILE_SIZE - 10), 0), Vector2i(10, TILE_SIZE)), Color(0.36, 0.37, 0.4))


func _draw_plate_tile(image: Image, tile: Vector2i, arrow: bool = false) -> void:
	var origin := tile * TILE_SIZE
	_fill_rect(image, Rect2i(origin + Vector2i(4, 4), Vector2i(24, 24)), Color(0.34, 0.35, 0.38))
	_fill_rect(image, Rect2i(origin + Vector2i(6, 6), Vector2i(20, 20)), Color(0.25, 0.26, 0.29))
	if arrow:
		_fill_rect(image, Rect2i(origin + Vector2i(14, 10), Vector2i(4, 10)), Color(0.44, 0.44, 0.46))
		_fill_rect(image, Rect2i(origin + Vector2i(10, 18), Vector2i(12, 4)), Color(0.44, 0.44, 0.46))
	else:
		_fill_rect(image, Rect2i(origin + Vector2i(12, 10), Vector2i(8, 8)), Color(0.44, 0.44, 0.46))


func _draw_brick_row(image: Image, origin: Vector2i, height: int, base_color: Color) -> void:
	var brick_widths := [10, 12, 10]
	var cursor: int = 0
	for width in brick_widths:
		var rect := Rect2i(origin + Vector2i(cursor, 0), Vector2i(width, height))
		_fill_rect(image, rect, base_color.darkened(_noise(rect.position.x, rect.position.y, width) * 0.08))
		_fill_rect(image, Rect2i(rect.position, Vector2i(rect.size.x, 1)), base_color.lightened(0.08))
		_fill_rect(image, Rect2i(rect.position + Vector2i(rect.size.x - 1, 0), Vector2i(1, rect.size.y)), Color(0.16, 0.16, 0.18))
		cursor += width


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				image.set_pixel(x, y, color)


func _noise(x: int, y: int, seed: int) -> float:
	var value: int = abs(x * 73856093 + y * 19349663 + seed * 83492791)
	return float(value % 100) / 100.0
