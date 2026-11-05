extends Node2D
## Cosmetic masonry uses integer coordinates, never the gameplay random stream.
var extent := Vector2(1000, 700)
var base := Color("181f23")
var accent := Color("354346")
func _draw() -> void:
	var half := extent * .5
	var rows := ceili(extent.y / 32)
	var columns := ceili(extent.x / 64)
	for y in range(rows):
		for x in range(columns + 1):
			var point := -half + Vector2(x * 64 - (32 if y % 2 else 0), y * 32)
			var rect := Rect2(point + Vector2.ONE, Vector2(62, 30)).intersection(Rect2(-half, extent))
			var value := posmod(x * 31 + y * 17, 13) / 13.0
			draw_rect(rect, base.lerp(accent, .07 + value * .12))
			if rect.size.x > 12:
				draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(accent, .13), 1)
			if value > .84:
				var origin := rect.get_center()
				draw_polyline(PackedVector2Array([origin + Vector2(-8, -6), origin, origin + Vector2(-3, 8)]), Color(base.darkened(.25), .6), 1)
	draw_rect(Rect2(-half + Vector2(8, 8), extent - Vector2(16, 16)), Color(accent, .35), false, 2)
