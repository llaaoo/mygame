@tool
class_name GeneratedAtlasSprite
extends Sprite2D

@export_file("*.png") var atlas_path: String = "res://content/art/prison/prison_tileset_concept.png"
@export var atlas_region: Rect2i = Rect2i(0, 0, 64, 64)


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if atlas_path.is_empty():
		return
	var atlas := load(atlas_path) as Texture2D
	if atlas == null:
		return
	texture = atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	region_enabled = true
	region_rect = Rect2(atlas_region.position, atlas_region.size)
