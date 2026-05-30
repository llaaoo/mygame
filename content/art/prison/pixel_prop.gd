@tool
class_name PixelProp
extends Sprite2D

@export_enum("bed", "table", "crate", "torch", "bars", "weapon_rack", "key_rack", "drain", "blood", "bookshelf", "altar", "barrel", "rug", "straw") var prop_type: String = "crate":
	set(value):
		prop_type = value
		_refresh_texture()

@export var pixel_size: int = 4:
	set(value):
		pixel_size = maxi(1, value)
		_refresh_texture()


func _ready() -> void:
	_refresh_texture()


func _refresh_texture() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint():
		return
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	match prop_type:
		"bed":
			_draw_rect(image, Rect2i(3, 4, 26, 22), Color(0.18, 0.11, 0.07))
			_draw_rect(image, Rect2i(6, 7, 20, 7), Color(0.18, 0.28, 0.42))
			_draw_rect(image, Rect2i(6, 17, 20, 7), Color(0.24, 0.17, 0.12))
		"table":
			_draw_rect(image, Rect2i(3, 9, 26, 12), Color(0.24, 0.14, 0.06))
			_draw_rect(image, Rect2i(5, 22, 5, 6), Color(0.13, 0.08, 0.04))
			_draw_rect(image, Rect2i(22, 22, 5, 6), Color(0.13, 0.08, 0.04))
		"crate":
			_draw_rect(image, Rect2i(4, 4, 24, 24), Color(0.23, 0.14, 0.06))
			_draw_rect(image, Rect2i(7, 7, 18, 4), Color(0.34, 0.22, 0.1))
			_draw_rect(image, Rect2i(14, 5, 4, 22), Color(0.13, 0.08, 0.04))
		"torch":
			_draw_rect(image, Rect2i(14, 10, 4, 18), Color(0.21, 0.11, 0.04))
			_draw_rect(image, Rect2i(11, 4, 10, 8), Color(0.95, 0.48, 0.08))
			_draw_rect(image, Rect2i(14, 2, 4, 8), Color(1.0, 0.78, 0.24))
		"bars":
			for x in [5, 12, 19, 26]:
				_draw_rect(image, Rect2i(x, 2, 3, 28), Color(0.08, 0.09, 0.1))
			_draw_rect(image, Rect2i(3, 6, 27, 3), Color(0.03, 0.04, 0.05))
			_draw_rect(image, Rect2i(3, 23, 27, 3), Color(0.03, 0.04, 0.05))
		"weapon_rack":
			_draw_rect(image, Rect2i(4, 22, 24, 4), Color(0.12, 0.08, 0.04))
			for x in [8, 15, 22]:
				_draw_rect(image, Rect2i(x, 5, 3, 20), Color(0.62, 0.64, 0.58))
				_draw_rect(image, Rect2i(x - 2, 13, 7, 2), Color(0.18, 0.1, 0.05))
		"key_rack":
			_draw_rect(image, Rect2i(5, 8, 22, 5), Color(0.22, 0.12, 0.04))
			for x in [9, 16, 23]:
				_draw_rect(image, Rect2i(x, 13, 2, 8), Color(0.78, 0.58, 0.18))
				_draw_rect(image, Rect2i(x - 2, 20, 6, 4), Color(0.78, 0.58, 0.18))
		"drain":
			_draw_rect(image, Rect2i(3, 10, 26, 12), Color(0.03, 0.05, 0.05))
			for x in range(6, 28, 5):
				_draw_rect(image, Rect2i(x, 11, 2, 10), Color(0.16, 0.18, 0.18))
		"blood":
			_draw_rect(image, Rect2i(8, 11, 16, 10), Color(0.32, 0.02, 0.02))
			_draw_rect(image, Rect2i(5, 16, 8, 5), Color(0.2, 0.01, 0.01))
			_draw_rect(image, Rect2i(21, 19, 5, 4), Color(0.25, 0.01, 0.01))
		"bookshelf":
			_draw_rect(image, Rect2i(3, 3, 26, 26), Color(0.16, 0.09, 0.04))
			for y in [7, 15, 23]:
				_draw_rect(image, Rect2i(5, y, 22, 2), Color(0.08, 0.05, 0.03))
			for x in range(6, 25, 5):
				_draw_rect(image, Rect2i(x, 8, 3, 6), Color(0.38, 0.24, 0.1))
		"altar":
			_draw_rect(image, Rect2i(5, 10, 22, 14), Color(0.17, 0.17, 0.18))
			_draw_rect(image, Rect2i(10, 6, 12, 5), Color(0.38, 0.34, 0.22))
			_draw_rect(image, Rect2i(13, 3, 6, 5), Color(0.85, 0.48, 0.1))
		"barrel":
			_draw_rect(image, Rect2i(8, 4, 16, 24), Color(0.24, 0.13, 0.05))
			_draw_rect(image, Rect2i(6, 9, 20, 4), Color(0.37, 0.25, 0.1))
			_draw_rect(image, Rect2i(6, 20, 20, 4), Color(0.37, 0.25, 0.1))
		"rug":
			_draw_rect(image, Rect2i(3, 7, 26, 18), Color(0.25, 0.04, 0.05))
			_draw_rect(image, Rect2i(7, 10, 18, 12), Color(0.45, 0.28, 0.12))
		"straw":
			for i in range(5, 28, 3):
				_draw_rect(image, Rect2i(i, 8 + (i % 5), 10, 2), Color(0.48, 0.37, 0.16))

	texture = ImageTexture.create_from_image(image)
	centered = true
	scale = Vector2.ONE * pixel_size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				image.set_pixel(x, y, color)
