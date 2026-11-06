class_name GrayriverTerrain
extends Node2D
## Low-node-count authored geography. Deep water collides; bridges and the ford are gaps.
var game: MVPGame
var layout: RunRoomLayout
var roads: Array = []
var _clock := 0.0
var _water_cells: Array[Vector2i] = []
var bridge_body: StaticBody2D
func _ready() -> void:
	z_index = -115
	roads = GrayriverDefinition.data().roads
	for obstacle in layout.obstacles: _body(obstacle.position, obstacle.size, "Terrain")
	var size := layout.arena_size
	for wall in [{"position":Vector2(0,-size.y/2-20),"size":Vector2(size.x,40)},{"position":Vector2(0,size.y/2+20),"size":Vector2(size.x,40)},{"position":Vector2(-size.x/2-20,0),"size":Vector2(40,size.y)},{"position":Vector2(size.x/2+20,0),"size":Vector2(40,size.y)}]: _body(wall.position,wall.size,"Boundary")
	if not game.progress.claims.has("river.bridge_fixed"): bridge_body = _body(Vector2(300,500),Vector2(260,400),"BrokenBridge")
	var center := SurfaceManager.cell_at(Vector2(300,2400))
	for x in range(-4,5):
		for y in range(-4,5):
			var cell := center + Vector2i(x,y)
			if (Vector2(cell*64)+Vector2(32,32)).distance_to(Vector2(300,2400)) <= 224: _water_cells.append(cell)
func _body(point: Vector2, size: Vector2, title: String) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = title
	body.position = point
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body
func _process(delta: float) -> void:
	if is_instance_valid(bridge_body) and game.progress.claims.has("river.bridge_fixed"):
		bridge_body.queue_free()
		bridge_body = null
		queue_redraw()
	_clock += delta
	if _clock < 1: return
	_clock = 0
	var surfaces := SurfaceManager.instance
	if not surfaces: return
	for cell in _water_cells:
		if str(surfaces.get_surface(cell).get("state","dry")) in ["dry","wet"]: surfaces.force_set_surface(cell,"wet",12,"灰河浅滩")
func _draw() -> void:
	draw_rect(Rect2(-layout.arena_size*.5,layout.arena_size),Color("42493a"))
	for patch in [{"rect":Rect2(-4500,-3100,2900,3400),"color":Color("263f32")},{"rect":Rect2(-1800,-3400,3300,1500),"color":Color("535950")},{"rect":Rect2(1700,-2300,2600,3600),"color":Color("54463b")},{"rect":Rect2(-300,1700,2600,1500),"color":Color("304d48")},{"rect":Rect2(-4500,1100,2300,2200),"color":Color("6a6249")}]: draw_rect(patch.rect,patch.color)
	# Riverbanks remain visible through the region; the shallow ford uses real surface cells.
	draw_line(Vector2(300,-3600),Vector2(300,3600),Color("203e46"),300)
	draw_line(Vector2(300,-3600),Vector2(300,3600),Color("345d69"),250)
	_lake(Vector2(650,-2800),Vector2(700,420),Color("345d69"))
	for road in roads:
		var points := PackedVector2Array()
		for p in road: points.append(GrayriverDefinition.vector(p))
		draw_polyline(points,Color("514936"),144,true)
		draw_polyline(points,Color("8e7d56"),105,true)
		draw_polyline(points,Color("9b895e"),8,true)
	for y in [-1500,2400]: draw_rect(Rect2(155,y-95,290,190),Color("777d6b") if y<0 else Color("42666b"))
	var repaired := game.progress.claims.has("river.bridge_fixed")
	draw_rect(Rect2(155,400,290,200),Color("8d704a") if repaired else Color("332c26"))
	if repaired:
		for x in range(165,435,24): draw_line(Vector2(x,410),Vector2(x,590),Color("574931"),3)
	else:
		draw_line(Vector2(170,420),Vector2(420,580),Color("b08a62"),12)
		draw_line(Vector2(170,580),Vector2(420,420),Color("b08a62"),12)
	for obstacle in layout.obstacles:
		if obstacle.get("kind","") == "water": continue
		var p:Vector2=obstacle.position
		var size:Vector2=obstacle.size
		if obstacle.get("kind","")=="tree":
			draw_rect(Rect2(p-Vector2(9,10),Vector2(18,28)),Color("4d3f2e"))
			draw_circle(p-Vector2(0,22),46,Color("1b3027"))
			draw_circle(p-Vector2(12,32),32,Color("355440"))
		else:
			draw_rect(Rect2(p-size*.5,size),Color("373b38"))
			draw_rect(Rect2(p-size*.5+Vector2(0,-20),Vector2(size.x,size.y*.6)),Color("65685a"))
	# Town roofs and market paving are decorative; services retain open approaches.
	for house in [Vector2(-4250,1450),Vector2(-4100,2800),Vector2(-2550,2650)]:
		draw_rect(Rect2(house-Vector2(120,80),Vector2(240,160)),Color("453e31"))
		draw_colored_polygon(PackedVector2Array([house+Vector2(-145,-50),house+Vector2(0,-150),house+Vector2(145,-50)]),Color("8b6548"))
		draw_rect(Rect2(house+Vector2(-20,10),Vector2(40,70)),Color("171f1b"))
func _lake(point: Vector2, size: Vector2, color: Color) -> void:
	var points:=PackedVector2Array()
	for i in range(48): points.append(point+Vector2(cos(i*TAU/48),sin(i*TAU/48))*size)
	draw_colored_polygon(points,color)
