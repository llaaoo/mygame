class_name GrayriverMap
extends Control
var game: GrayriverGame
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var local_mode := false
func _ready() -> void:
	local_mode=game.current_data.map_scene!=null and not game.current_data.open_field
	custom_minimum_size=Vector2(0,160)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	resized.connect(_limit_pan)
func _scale() -> Vector2:
	if local_mode:
		var ratio: Vector2=(size-Vector2(80,100))/game.current_data.authored_size
		return Vector2.ONE*maxf(.05,minf(ratio.x,ratio.y))*zoom
	return Vector2(maxf(200,size.x-40),maxf(40,size.y-55))/Vector2(9600,7200)*zoom
func set_local(value: bool) -> void:
	local_mode=value; zoom=1; pan=Vector2.ZERO; center_player()
func project(point: Vector2) -> Vector2:
	return size*.5+pan+point*_scale()
func unproject(point: Vector2) -> Vector2:
	return (point-size*.5-pan)/_scale()
func center_player() -> void:
	var point: Vector2=game.player.position if local_mode or game.region_id=="camp" else game.guidance.overworld_point(game.region_id)
	pan=-point*_scale()
	_limit_pan()
func _limit_pan() -> void:
	pan=pan.clamp(-size*zoom*.5,size*zoom*.5)
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]: dragging=event.pressed; accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor:=unproject(event.position)
			zoom=clampf(zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2),1,4)
			pan=event.position-size*.5-anchor*_scale()
			_limit_pan(); accept_event()
		elif event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			game.guidance.set_waypoint(unproject(event.position),game.region_id if local_mode else "camp"); queue_redraw(); accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan+=event.relative; _limit_pan(); accept_event()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("132226"))
	if local_mode:
		_draw_local()
		return
	draw_rect(Rect2(project(Vector2(-4800,-3600)),Vector2(9600,7200)*_scale()),Color("334138"))
	draw_line(project(Vector2(300,-3600)),project(Vector2(300,3600)),Color("426875"),15)
	var lake:=PackedVector2Array()
	for i in range(32):lake.append(project(Vector2(650,-2800)+Vector2(cos(i*TAU/32),sin(i*TAU/32))*Vector2(700,420)))
	draw_colored_polygon(lake,Color("426875"))
	for road in game.definition.roads:
		var points:=PackedVector2Array()
		for p in road: points.append(project(GrayriverDefinition.vector(p)))
		draw_polyline(points,Color("1e2c27"),6,true)
		draw_polyline(points,Color("ae9b74"),2,true)
	for x in range(-10,10):
		for y in range(-8,8):
			if game.progress.claims.has("fog.%d.%d"%[x,y]): continue
			var a:=project(Vector2(x*512,y*512))
			var b:=project(Vector2((x+1)*512,(y+1)*512))
			var box:=Rect2(a,b-a).intersection(Rect2(Vector2(20,30),Vector2(maxf(200,size.x-40),maxf(40,size.y-55))))
			if box.has_area():draw_rect(box,Color(0,0,0,.64))
	var font:=get_theme_default_font()
	var goal:=game.guidance.tracked()
	if not goal.is_empty() and goal.known:
		var point: Vector2=goal.position if goal.region=="camp" else game.guidance.overworld_point(goal.region)
		var marker:=project(point)
		draw_arc(marker,9,0,TAU,24,GameUIStyle.GOLD,2)
		draw_string(font,marker+Vector2(12,15),goal.title,HORIZONTAL_ALIGNMENT_LEFT,-1,13,GameUIStyle.GOLD)
	for place in game.definition.landmarks:
		if not game.progress.claims.has("place."+place.id):continue
		var p:=project(GrayriverDefinition.vector(place.pos))
		draw_circle(p,4,GameUIStyle.GOLD)
		draw_string(font,p+Vector2(6,-5),place.title,HORIZONTAL_ALIGNMENT_LEFT,-1,13,GameUIStyle.TEXT_MAIN)
	for door in game.catalog.regions.camp.exits:
		if not game.catalog.regions[door.target].map_scene or not game.guidance.known("camp",door.pos): continue
		var p:=project(door.pos)
		draw_rect(Rect2(p-Vector2(4,4),Vector2(8,8)),GameUIStyle.GOLD,false,2)
		draw_string(font,p+Vector2(7,12),game.catalog.regions[door.target].title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,GameUIStyle.TEXT_MAIN)
	if game.progress.claims.has("fog.0.0"):
		var bridge:=project(Vector2(300,500))
		draw_circle(bridge,4,GameUIStyle.GOLD)
		draw_string(font,bridge+Vector2(6,-5),"木桥 · "+("已修复" if game.progress.claims.has("river.bridge_fixed") else "损坏"),HORIZONTAL_ALIGNMENT_LEFT,-1,13,GameUIStyle.TEXT_MAIN)
	for record: Dictionary in game.progress.loot_records.values():
		if record.region != "camp" or (record.equipment.is_empty() and record.materials.is_empty()): continue
		var at := project(GrayriverDefinition.vector(record.position))
		draw_line(at-Vector2(3,3),at+Vector2(3,3),Color("e2ab66"),2)
		draw_line(at+Vector2(-3,3),at+Vector2(3,-3),Color("e2ab66"),2)
	var position:=game.player.position
	if game.region_id!="camp": position=game.guidance.overworld_point(game.region_id)
	draw_circle(project(position),5,Color("70deff"))
	draw_string(font,Vector2(24,20),"蓝点：你 / 入口    橙叉：未取物资    暗处：未探索",HORIZONTAL_ALIGNMENT_LEFT,-1,12,GameUIStyle.TEXT_MAIN)
	var north:=Vector2(size.x-42,55)
	draw_arc(north,23,0,TAU,32,Color(GameUIStyle.GOLD,.55),1,true)
	draw_colored_polygon(PackedVector2Array([north+Vector2(0,-20),north+Vector2(-6,11),north,north+Vector2(6,11)]),GameUIStyle.GOLD)
	draw_string(font,north+Vector2(-7,-29),"北",HORIZONTAL_ALIGNMENT_LEFT,-1,12,GameUIStyle.TEXT_MAIN)

func _draw_local() -> void:
	var region:=game.current_data
	var font:=get_theme_default_font()
	var start:=project(-region.authored_size*.5)
	draw_rect(Rect2(start,region.authored_size*_scale()),Color("635e4f"))
	for obstacle in region.authored_obstacles:
		draw_rect(Rect2(project(obstacle.position-obstacle.size*.5),obstacle.size*_scale()),Color("a59a7c"))
	for point in region.interaction_points():
		var at:=project(point.pos)
		draw_circle(at,4,Color("86b6b6") if point is ExplorationExitData else GameUIStyle.GOLD)
		draw_string(font,at+Vector2(7,-6),point.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,GameUIStyle.TEXT_MAIN)
	var goal:=game.guidance.tracked()
	var target:=game.guidance.route_target(goal)
	if target.is_finite(): draw_arc(project(target),10,0,TAU,24,GameUIStyle.GOLD,2)
	draw_circle(project(game.player.position),5,Color("70deff"))
	draw_string(font,Vector2(24,23),region.title+" · 蓝点：你 / 蓝标：出口 / 金标：交互",HORIZONTAL_ALIGNMENT_LEFT,-1,13,GameUIStyle.TEXT_MAIN)
