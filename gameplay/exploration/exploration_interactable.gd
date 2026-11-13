class_name ExplorationInteractable
extends Node2D
var harvest_ready_query: Callable

var world_art := false
var marker_art := true
var title := "交互"
var tint := Color(0.95, 0.7, 0.25)
var callback: Callable
var kind := "note"
var _label: Label
var _player: Node2D
var _label_time := 0.0
var _near := false
var provider: InteractionProvider
var _visitor: Node2D
var presentation: WorldObjectPresentation
@export var presentation_profile: WorldAnimationProfile

func _ready() -> void:
	match kind:
		"person": tint = Color(0.4, 0.95, 0.65)
		"passage": tint = Color(0.45, 0.75, 1.0)
		"mechanism": tint = Color(0.85, 0.6, 1.0)
	add_to_group("interactable")
	var interaction := Interactable.new()
	interaction.name = "Interactable"
	provider=InteractionProvider.new()
	provider.available=func(_id: String):
		return is_instance_valid(_visitor) and is_inside_tree() and _visitor.global_position.distance_to(global_position)<80 and visible_from(_visitor)
	provider.options=func(_id: String):
		var option:=InteractionOption.new()
		option.id="interact"; option.title=title
		option.request=func():
			if not callback.is_valid(): return false
			callback.call()
			return true
		return [option]
	add_child(provider)
	interaction.set_callback(func(actor: Node2D):
		_visitor=actor
		provider.execute(str(actor.get_instance_id()),"interact"))
	add_child(interaction)
	_label = Label.new()
	_label.position = Vector2(-100, -47)
	_label.size = Vector2(200, 32)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", tint)
	add_child(_label)
	set_title(title)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_update_proximity()
	presentation=WorldObjectPresentation.new(); presentation.name="WorldPresentation"; presentation.query=presentation_snapshot
	add_child(presentation)
	queue_redraw()

func visible_from(actor: Node2D) -> bool:
	if not is_inside_tree() or not is_instance_valid(actor): return false
	var ray:=PhysicsRayQueryParameters2D.create(actor.global_position,global_position,1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func presentation_snapshot() -> Dictionary:
	var station:=get_meta("survival_station") as SurvivalStationData if has_meta("survival_station") else null
	var form:=kind
	var state:="active" if _near else "idle"
	var offset:=Vector2.ZERO
	if get_meta("survival_rest",false): form="hearth" if marker_art else "bed"; state="active"
	elif station:
		form=station.kind
		if form=="cook":
			form="hearth"; offset=station.heat_offset
			var burning: bool=station.lit or is_instance_valid(SurfaceManager.instance) and SurfaceManager.instance.surface_at(global_position+offset).get("state","dry")=="burning"
			state="active" if burning else "idle"
		elif form=="forage" and harvest_ready_query.is_valid(): state="idle" if harvest_ready_query.call() else "depleted"
	return {"kind":form,"state":state,"offset":offset,"focused":_near,"color":tint,"profile":station.presentation_profile if station and station.presentation_profile else presentation_profile}

func set_title(value: String) -> void:
	title = value
	if _label:
		_label.text = ("[F] " if _near else "") + title

func _process(delta: float) -> void:
	_label_time += delta
	if _label_time >= .15:
		_label_time = 0
		_update_proximity()

func _update_proximity() -> void:
	if not is_instance_valid(_player): return
	var distance := global_position.distance_squared_to(_player.global_position)
	var near := _player is Player and (_player as Player).input_controller.interaction_target() == self
	if _near != near:
		_near = near
		set_title(title)
		queue_redraw()
	_label.visible = not world_art and (near or (kind in ["passage", "person"] and distance < 180*180))
	if _player is Player and _player.ui_blocked: _label.visible=false
	_label.modulate.a = 1.0 if near else .7
	var fuel_hint:=get_node_or_null("FuelHint") as Label
	if fuel_hint: fuel_hint.visible=distance<180*180
	if world_art and has_meta("survival_station"): queue_redraw()

func _draw() -> void:
	if not marker_art:
		if _near: draw_arc(Vector2.ZERO,22,0,TAU,32,Color(tint,.6),1,true)
		return
	if presentation and presentation.has_body_art(): return
	if world_art:
		_draw_frontier()
		return
	if _near: draw_arc(Vector2.ZERO, 25, 0, TAU, 32, Color(tint, .35), 1, true)
	draw_circle(Vector2.ZERO, 19, Color(tint, 0.18))
	draw_arc(Vector2.ZERO, 20, 0, TAU, 32, tint, 2, true)
	match kind:
		"cache":
			draw_rect(Rect2(-12,-8,24,18),Color("76573c"))
			draw_rect(Rect2(-12,-8,24,18),tint,false,2)
			draw_line(Vector2(-12,-2),Vector2(12,-2),tint,2)
			draw_rect(Rect2(-2,-4,4,7),tint)
		"person":
			draw_circle(Vector2(0, -6), 5, tint)
			draw_line(Vector2(0, 0), Vector2(0, 10), tint, 3)
			draw_line(Vector2(-8, 4), Vector2(8, 4), tint, 2)
		"passage":
			draw_line(Vector2(-8, 0), Vector2(8, 0), tint, 3)
			draw_polyline(PackedVector2Array([Vector2(1, -8), Vector2(9, 0), Vector2(1, 8)]), tint, 2)
		"mechanism":
			draw_rect(Rect2(-8, -8, 16, 16), tint, false, 2)
			draw_line(Vector2(-10, 10), Vector2(10, -10), tint, 2)
		_:
			draw_rect(Rect2(-7, -10, 14, 20), tint, false, 2)
			draw_line(Vector2(-4, -3), Vector2(4, -3), tint, 1)
			draw_line(Vector2(-4, 3), Vector2(4, 3), tint, 1)

func _draw_frontier() -> void:
	draw_set_transform(Vector2(0,4),0,Vector2(1,.45))
	draw_circle(Vector2.ZERO,22,Color(0,0,0,.22))
	draw_set_transform(Vector2.ZERO)
	if _near: draw_arc(Vector2.ZERO,26,0,TAU,32,Color(tint,.7),1,true)
	var resource_station:=get_meta("survival_station") as SurvivalStationData if has_meta("survival_station") else null
	if resource_station and resource_station.kind=="forage":
		_draw_resource(resource_station)
		return
	match kind:
		"person":
			draw_rect(Rect2(-8,0,6,18),Color("353c3a"))
			draw_rect(Rect2(2,0,6,18),Color("353c3a"))
			draw_rect(Rect2(-12,-20,24,27),Color("72735c"))
			draw_rect(Rect2(-8,-34,16,16),Color("bc9a78"))
			draw_rect(Rect2(-9,-37,18,7),Color("464138"))
			draw_line(Vector2(-8,-4),Vector2(8,-4),Color("b4a47e"),3)
		"passage":
			for x in [-19,19]: draw_rect(Rect2(x-5,-14,10,32),Color("6f7468"))
			draw_rect(Rect2(-24,-20,48,10),Color("868a77"))
			draw_polyline(PackedVector2Array([Vector2(-7,0),Vector2(4,-7),Vector2(4,7)]),Color("d1bf8b"),2)
		"mechanism":
			var station:=get_meta("survival_station") as SurvivalStationData if has_meta("survival_station") else null
			if get_meta("survival_rest",false):
				_draw_hearth(Vector2.ZERO,true)
				return
			if station and station.kind=="water":
				texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				FrontierArt.tile(self,Vector2i(8,8),Rect2(-25,-28,50,50),Color("bdb8a4"))
				return
			if station and station.kind=="cook":
				var burning: bool=station.lit or SurfaceManager.instance.surface_at(global_position+station.heat_offset).get("state","dry")=="burning"
				_draw_hearth(station.heat_offset,burning)
			draw_rect(Rect2(-20,-10,40,20),Color("6f5b40"))
			for x in [-14,14]: draw_line(Vector2(x,5),Vector2(x,18),Color("443b2c"),5)
			draw_line(Vector2(-13,-10),Vector2(8,0),Color("afaa8a"),3)
		_:
			draw_rect(Rect2(-15,-8,30,22),Color("6e563a"))
			draw_rect(Rect2(-16,-11,32,8),Color("9a8155"))
			if kind!="cache":
				draw_rect(Rect2(-9,-15,18,13),Color("c6b78d"))
				draw_line(Vector2(-6,-11),Vector2(6,-11),Color("71674f"),1)
	if _near:
		draw_colored_polygon(PackedVector2Array([Vector2(-4,-46),Vector2(4,-46),Vector2(0,-40)]),GameUIStyle.GOLD)

func _draw_hearth(point: Vector2, lit: bool) -> void:
	for i in range(8):
		var at:=point+Vector2.from_angle(i*TAU/8)*Vector2(21,13)
		draw_circle(at,6,Color("6d7164"))
	draw_line(point+Vector2(-14,-5),point+Vector2(14,5),Color("5c4934"),6)
	draw_line(point+Vector2(-14,5),point+Vector2(14,-5),Color("7b6345"),5)
	if lit:
		for radius in [48,34,22]: draw_circle(point,radius,Color(1,.55,.18,.035))
		draw_colored_polygon(PackedVector2Array([point+Vector2(-13,1),point+Vector2(-8,-23),point+Vector2(-1,-16),point+Vector2(5,-35),point+Vector2(13,1)]),Color("d68d49"))
		draw_colored_polygon(PackedVector2Array([point+Vector2(-7,2),point+Vector2(1,-18),point+Vector2(7,2)]),Color("eec780"))

func _draw_resource(station: SurvivalStationData) -> void:
	var ready: bool=harvest_ready_query.call() if harvest_ready_query.is_valid() else true
	var shade:=Color.WHITE if ready else Color(.4,.4,.4)
	if station.harvest.has("charcoal"):
		draw_line(Vector2(-25,7),Vector2(22,-9),Color("66503a")*shade,16,true)
		draw_circle(Vector2(-25,7),8,Color("ab9061")*shade)
		draw_line(Vector2(-17,0),Vector2(19,-12),Color("89734e")*shade,3,true)
	elif station.harvest.has("crystal") or station.harvest.has("frost_salt"):
		var c:=Color("b8dbe3") if station.harvest.has("frost_salt") else Color("92a9bb")
		draw_colored_polygon(PackedVector2Array([Vector2(-25,10),Vector2(-21,-9),Vector2(1,-18),Vector2(23,-4),Vector2(27,12)]),Color("5d6668")*shade)
		for x in [-12,3,15]: draw_colored_polygon(PackedVector2Array([Vector2(x-6,3),Vector2(x,-22-abs(x)*.4),Vector2(x+6,-3)]),c*shade)
	else:
		for x in [-14,0,14]:
			draw_line(Vector2(x,12),Vector2(x,-10),Color("78885b")*shade,3,true)
			draw_circle(Vector2(x,-12),7,Color("9ba16b")*shade)
