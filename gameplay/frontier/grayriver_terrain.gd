class_name GrayriverTerrain
extends Node2D
## Low-node-count authored geography. Deep water collides; bridges and the ford are gaps.
var game: CampaignGame
var layout: RunRoomLayout
var roads: Array = []
var _clock := 0.0
var _water_cells: Array[Vector2i] = []
var bridge_body: StaticBody2D
var _view := Rect2()
var _landmarks: Node2D
func _ready() -> void:
	z_index = -115
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var palette:=ShaderMaterial.new()
	palette.shader=preload("res://gameplay/frontier/land_palette.gdshader")
	material=palette
	roads = GrayriverDefinition.data().roads
	for obstacle in layout.obstacles: _body(obstacle.position, obstacle.size, "Terrain")
	var lake_body:=StaticBody2D.new()
	lake_body.collision_layer=1
	lake_body.collision_mask=0
	var lake_shape:=CollisionShape2D.new()
	var shape:=ConvexPolygonShape2D.new()
	var points:=PackedVector2Array()
	for i in range(48):points.append(Vector2(650,-2800)+Vector2(cos(i*TAU/48),sin(i*TAU/48))*Vector2(700,420))
	shape.points=points
	lake_shape.shape=shape
	lake_body.add_child(lake_shape)
	add_child(lake_body)
	var navigation:=game.session.region.navigation
	if navigation:
		for x in range(-2,36):
			for y in range(-82,-58):
				var point:=Vector2(x,y)*RegionNavigation.CELL
				if ((point-Vector2(650,-2800))/Vector2(720,440)).length()<=1:
					navigation.set_obstacle(Rect2(point,Vector2.ONE*RegionNavigation.CELL),true)
	var size := layout.arena_size
	for wall in [{"position":Vector2(0,-size.y/2-20),"size":Vector2(size.x,40)},{"position":Vector2(0,size.y/2+20),"size":Vector2(size.x,40)},{"position":Vector2(-size.x/2-20,0),"size":Vector2(40,size.y)},{"position":Vector2(size.x/2+20,0),"size":Vector2(40,size.y)}]: _body(wall.position,wall.size,"Boundary")
	if not game.progress.claims.has("river.bridge_fixed"):
		bridge_body = _body(Vector2(300,500),Vector2(260,400),"BrokenBridge")
		if navigation: navigation.set_obstacle(Rect2(170,300,260,400).grow(20),true)
	var center := SurfaceManager.cell_at(Vector2(300,2400))
	for x in range(-4,5):
		for y in range(-4,5):
			var cell := center + Vector2i(x,y)
			if (Vector2(cell*64)+Vector2(32,32)).distance_to(Vector2(300,2400)) <= 224: _water_cells.append(cell)
	# Separate water material keeps animated ripples off the land and interface.
	var water:=Node2D.new()
	water.name="RiverWater"
	var water_material:=ShaderMaterial.new()
	water_material.shader=preload("res://gameplay/frontier/river_water.gdshader")
	water.material=water_material
	add_child(water)
	water.draw.connect(func():
		water.draw_rect(Rect2(175,-3600,250,7200),Color.WHITE)
		var lake:=PackedVector2Array()
		for i in range(64): lake.append(Vector2(650,-2800)+Vector2.from_angle(i*TAU/64)*Vector2(700,420))
		water.draw_colored_polygon(lake,Color.WHITE))
	_landmarks=Node2D.new()
	_landmarks.name="GeographyArt"
	_landmarks.material=material
	add_child(_landmarks)
	_landmarks.draw.connect(_draw_landmarks)
	_refresh_view()
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
	_refresh_view()
	if is_instance_valid(bridge_body) and game.progress.claims.has("river.bridge_fixed"):
		bridge_body.queue_free()
		bridge_body = null
		if game.session.region.navigation: game.session.region.navigation.set_obstacle(Rect2(170,300,260,400).grow(20),false)
		queue_redraw()
		_landmarks.queue_redraw()
	_clock += delta
	if _clock < 1: return
	_clock = 0
	var surfaces := SurfaceManager.instance
	if not surfaces: return
	for cell in _water_cells:
		if str(surfaces.get_surface(cell).get("state","dry")) in ["dry","wet"]: surfaces.force_set_surface(cell,"wet",12,"灰河浅滩")
func _refresh_view() -> void:
	var camera:=get_viewport().get_camera_2d()
	if not camera: return
	var size:=get_viewport_rect().size/camera.zoom
	var next:=Rect2(camera.get_screen_center_position()-size*.5,size).grow(192)
	if _view.size!=next.size or _view.get_center().distance_to(next.get_center())>96:
		_view=next
		queue_redraw()
		if _landmarks: _landmarks.queue_redraw()

func _draw() -> void:
	var bounds:=Rect2(-layout.arena_size*.5,layout.arena_size)
	draw_rect(bounds,Color("4b5946"))
	var visible_ground:=_view.intersection(bounds)
	# Only the camera's cells are submitted. Stable coordinate variation never uses gameplay RNG.
	for x in range(floori(visible_ground.position.x/48),ceili(visible_ground.end.x/48)):
		for y in range(floori(visible_ground.position.y/48),ceili(visible_ground.end.y/48)):
			var p:=Vector2(x,y)*48
			var variation:=posmod(hash(Vector2i(x,y)),97)
			var tint:=Color("839279")
			if p.x>1400: tint=tint.lerp(Color("9c8372"),clampf((p.x-1400)/2200,0,.7))
			if p.y< -1700: tint=tint.lerp(Color("7c8985"),clampf((-p.y-1700)/1800,0,.65))
			if p.x< -2100 and p.y>1100: tint=tint.lerp(Color("aeaa7e"),.32)
			tint=tint.darkened((sin(x*.21)+cos(y*.18))*.015+.03)
			FrontierArt.tile(self,Vector2i(1 if variation<4 else 0,0),Rect2(p,Vector2.ONE*48),tint)
	# Organic banks replace the old hard biome rectangles.
	draw_line(Vector2(300,-3600),Vector2(300,3600),Color("354f48"),326)
	draw_line(Vector2(300,-3600),Vector2(300,3600),Color("50675b"),286)
	_lake(Vector2(650,-2800),Vector2(730,448),Color("50675b"))
	for road in roads:
		var points:=PackedVector2Array()
		for p in road: points.append(GrayriverDefinition.vector(p))
		draw_polyline(points,Color("5c6049"),144,true)
		draw_polyline(points,Color("77765a"),122,true)
		draw_polyline(points,Color("93866a"),105,true)
		for i in range(points.size()-1):
			var a:=points[i]; var b:=points[i+1]
			var steps:=maxi(1,int(a.distance_to(b)/40))
			for j in range(steps):
				var p:=a.lerp(b,float(j)/steps)
				if not _view.has_point(p): continue
				FrontierArt.tile(self,Vector2i(1,2),Rect2(p-Vector2(24,24),Vector2(48,48)),Color("b7b198"))

func _draw_landmarks() -> void:
	var art:=_landmarks
	for y in [-1500,2400]:
		art.draw_rect(Rect2(155,y-95,290,190),Color("777d6b") if y<0 else Color(.35,.47,.44,.55))
		if y<0:
			for x in range(160,440,24):
				art.draw_rect(Rect2(x,y-88,21,176),Color("8d8870"))
	var repaired:=game.progress.claims.has("river.bridge_fixed")
	art.draw_rect(Rect2(155,400,290,200),Color("8d704a") if repaired else Color("332c26"))
	if repaired:
		for x in range(165,435,24): art.draw_line(Vector2(x,410),Vector2(x,590),Color("574931"),3)
	else:
		art.draw_line(Vector2(170,420),Vector2(420,580),Color("b08a62"),12)
		art.draw_line(Vector2(170,580),Vector2(420,420),Color("b08a62"),12)
	for obstacle in layout.obstacles:
		if obstacle.get("kind","")=="water": continue
		var p:Vector2=obstacle.position
		var size:Vector2=obstacle.size
		if not _view.grow(120).has_point(p): continue
		if obstacle.get("kind","")=="tree":
			art.draw_set_transform(p+Vector2(8,10),0,Vector2(1,.4))
			art.draw_circle(Vector2.ZERO,48,Color(0,0,0,.19))
			art.draw_set_transform(Vector2.ZERO)
			FrontierArt.region(art,Rect2(64,0,16,32),Rect2(p-Vector2(48,115),Vector2(96,144)),Color("a2ad94"))
		else:
			art.draw_rect(Rect2(p-size*.5,size),Color("393f39"))
			FrontierArt.tile(art,Vector2i(3,8),Rect2(p-size*.5-Vector2(0,12),size),Color("a3a597"))
	for house in [Vector2(-4250,1450),Vector2(-4100,2800),Vector2(-2550,2650)]:
		if _view.grow(260).has_point(house): FrontierArt.house(art,house)

func _lake(point: Vector2, size: Vector2, color: Color) -> void:
	var points:=PackedVector2Array()
	for i in range(64): points.append(point+Vector2.from_angle(i*TAU/64)*size)
	draw_colored_polygon(points,color)
