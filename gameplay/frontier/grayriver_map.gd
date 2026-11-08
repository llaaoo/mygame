class_name GrayriverMap
extends Control
var game: GrayriverGame
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
func _ready() -> void:
	custom_minimum_size=Vector2(0,340)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	resized.connect(_limit_pan)
func _scale() -> Vector2:
	return Vector2(maxf(200,size.x-40),maxf(180,size.y-55))/Vector2(9600,7200)*zoom
func project(point: Vector2) -> Vector2:
	return size*.5+pan+point*_scale()
func unproject(point: Vector2) -> Vector2:
	return (point-size*.5-pan)/_scale()
func center_player() -> void:
	var point: Vector2=game.player.position if game.region_id=="camp" else game.guidance.overworld_point(game.region_id)
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
			game.guidance.set_waypoint(unproject(event.position)); queue_redraw(); accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan+=event.relative; _limit_pan(); accept_event()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("1d2927"))
	draw_rect(Rect2(project(Vector2(-4800,-3600)),Vector2(9600,7200)*_scale()),Color("3e493a"))
	draw_line(project(Vector2(300,-3600)),project(Vector2(300,3600)),Color("426875"),15)
	var lake:=PackedVector2Array()
	for i in range(32):lake.append(project(Vector2(650,-2800)+Vector2(cos(i*TAU/32),sin(i*TAU/32))*Vector2(700,420)))
	draw_colored_polygon(lake,Color("426875"))
	for road in game.definition.roads:
		var points:=PackedVector2Array()
		for p in road: points.append(project(GrayriverDefinition.vector(p)))
		draw_polyline(points,Color("998761"),3,true)
	for x in range(-10,10):
		for y in range(-8,8):
			if game.progress.claims.has("fog.%d.%d"%[x,y]): continue
			var a:=project(Vector2(x*512,y*512))
			var b:=project(Vector2((x+1)*512,(y+1)*512))
			var box:=Rect2(a,b-a).intersection(Rect2(Vector2(20,30),Vector2(maxf(200,size.x-40),maxf(180,size.y-55))))
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
	draw_string(font,Vector2(24,20),"北 ↑  蓝点：你/入口  橙叉：未取物资  暗处：未探索",HORIZONTAL_ALIGNMENT_LEFT,-1,13,GameUIStyle.TEXT_MAIN)
