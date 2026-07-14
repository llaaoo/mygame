class_name SkillIconCatalog
extends RefCounted

const ATLAS_PATH := "res://content/art/pixel/spell_icons_atlas.png"
const COLUMNS := 6
const ROWS := 5


static func get_icon(skill: SkillData) -> Texture2D:
	if not skill:
		return null
	if skill.icon:
		return skill.icon
	return get_icon_by_index(skill.icon_atlas_index)


static func get_icon_by_index(index: int) -> Texture2D:
	if index < 0 or index >= COLUMNS * ROWS:
		return null
	var atlas := ResourceLoader.load(ATLAS_PATH) as Texture2D
	if not atlas:
		return null
	var size: Vector2 = atlas.get_size()
	var cell := Vector2(size.x / float(COLUMNS), size.y / float(ROWS))
	var column := index % COLUMNS
	var row := index / COLUMNS
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(column, row) * cell, cell)
	return texture
