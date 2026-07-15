class_name EquipmentIconCatalog
extends RefCounted

const ATLAS_PATH := "res://content/art/pixel/equipment/equipment_atlas.png"
const COLUMNS := 6
const ROWS := 6


static func get_icon_by_index(index: int) -> Texture2D:
	if index < 0 or index >= COLUMNS * ROWS:
		return null
	var atlas := ResourceLoader.load(ATLAS_PATH) as Texture2D
	if not atlas:
		return null
	var size := atlas.get_size()
	var cell := Vector2(size.x / float(COLUMNS), size.y / float(ROWS))
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(index % COLUMNS, index / COLUMNS) * cell, cell)
	return texture
