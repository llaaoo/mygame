class_name GrayriverMap
extends Control
var game: GrayriverGame
func _ready() -> void:
	custom_minimum_size=Vector2(0,420)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func project(point: Vector2) -> Vector2:
	return Vector2(20,30)+(point/Vector2(9600,7200)+Vector2(.5,.5))*Vector2(maxf(200,size.x-40),360)
func _draw() -> void:
	draw_rect(Rect2(Vector2(20,30),Vector2(maxf(200,size.x-40),360)),Color("3e493a"))
	draw_line(project(Vector2(300,-3600)),project(Vector2(300,3600)),Color("426875"),15)
	for road in game.definition.roads:
		var points:=PackedVector2Array()
		for p in road: points.append(project(GrayriverDefinition.vector(p)))
		draw_polyline(points,Color("998761"),3,true)
	for x in range(-10,10):
		for y in range(-8,8):
			if game.progress.claims.has("fog.%d.%d"%[x,y]): continue
			var a:=project(Vector2(x*512,y*512))
			var b:=project(Vector2((x+1)*512,(y+1)*512))
			var box:=Rect2(a,b-a).intersection(Rect2(Vector2(20,30),Vector2(maxf(200,size.x-40),360)))
			if box.has_area():draw_rect(box,Color(0,0,0,.64))
	var font:=get_theme_default_font()
	for place in game.definition.landmarks:
		if not game.progress.claims.has("place."+place.id):continue
		var p:=project(GrayriverDefinition.vector(place.pos))
		draw_circle(p,4,GameUIStyle.GOLD)
		draw_string(font,p+Vector2(6,-5),place.title,HORIZONTAL_ALIGNMENT_LEFT,-1,13,GameUIStyle.TEXT_MAIN)
	var position:=game.player.position
	if game.region_id!="camp": position=game.catalog.regions[game.region_id].exits[0].arrival
	draw_circle(project(position),5,Color("70deff"))
	draw_string(font,Vector2(24,20),"北 ↑   蓝点：你 / 遗迹入口   暗处：尚未走过",HORIZONTAL_ALIGNMENT_LEFT,-1,13,GameUIStyle.TEXT_MAIN)
