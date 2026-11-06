class_name RegionNavigation
extends RefCounted
const CELL := 40.0
var grid: AStarGrid2D
var bounds: Rect2
func configure(layout: RunRoomLayout) -> void:
	bounds=Rect2(-layout.arena_size*.5,layout.arena_size)
	grid=AStarGrid2D.new()
	grid.region=Rect2i(Vector2i.ZERO,Vector2i(ceili(bounds.size.x/CELL),ceili(bounds.size.y/CELL)))
	grid.cell_size=Vector2.ONE*CELL
	grid.offset=bounds.position+Vector2.ONE*CELL*.5
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for obstacle in layout.obstacles:
		set_obstacle(Rect2(obstacle.position-obstacle.size*.5,obstacle.size).grow(20),true)
func cell(point: Vector2) -> Vector2i:
	return Vector2i((point-bounds.position)/CELL)
func set_obstacle(rect: Rect2, solid: bool) -> void:
	if not grid: return
	var a:=cell(rect.position)
	var b:=cell(rect.end)
	for x in range(a.x,b.x+1):
		for y in range(a.y,b.y+1):
			var p:=Vector2i(x,y)
			if grid.is_in_boundsv(p): grid.set_point_solid(p,solid)
func path(from: Vector2,to: Vector2) -> PackedVector2Array:
	if not grid: return PackedVector2Array()
	var a:=cell(from)
	var b:=cell(to)
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b) or grid.is_point_solid(a) or grid.is_point_solid(b): return PackedVector2Array()
	return grid.get_point_path(a,b)
func direction(from: Vector2,to: Vector2) -> Vector2:
	var route:=path(from,to)
	if route.is_empty(): return Vector2.ZERO
	for point in route:
		if point.distance_to(from)>22: return (point-from).normalized()
	return (to-from).normalized()
