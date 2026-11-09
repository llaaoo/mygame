class_name SpellWorldObject
extends Area2D
## Spell puzzles consume hit events, including zero-damage utility hits.
signal solved(spec: SpellPuzzleData)
signal inspected(spec: SpellPuzzleData, completed: bool)
var world_art := false
var spec: SpellPuzzleData
var completed := false
var part_taken := false
var eligibility: Callable
var completion_handler: Callable
var _steps: Array[int] = []
var _held: Array[float] = []
var _label: Label
var _bus: CombatEventBus
var presentation: WorldObjectPresentation

func _ready() -> void:
	collision_layer = 0 if completed else 8
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22
	shape.shape = circle
	add_child(shape)
	set_process(false)
	RuntimeRegistration.register_ticker(self)
	for route in spec.routes:
		_steps.append(0)
		_held.append(0.0)
	_label = Label.new()
	_label.position = Vector2(-120, -55)
	_label.size.x = 240
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	add_child(_label)
	_refresh()
	_bus = RuntimeRegistration.combat_bus_for(self)
	if is_instance_valid(_bus):
		_bus.subscribe(CombatEvent.Type.ON_HIT, _on_hit)
	add_to_group("interactable")
	var interaction := Interactable.new()
	interaction.name = "Interactable"
	interaction.set_callback(func(_actor: Node2D): inspected.emit(spec, completed))
	add_child(interaction)
	presentation=WorldObjectPresentation.new(); presentation.name="WorldPresentation"; presentation.query=presentation_snapshot
	add_child(presentation)

func presentation_snapshot() -> Dictionary:
	var active:=false
	for step in _steps:
		if step>0: active=true
	return {"kind":"mechanism","state":"complete" if completed else "active" if active else "idle","color":GameUIStyle.SUCCESS if completed else GameUIStyle.GOLD,"profile":spec.presentation_profile}

func _exit_tree() -> void:
	if is_instance_valid(_bus):
		_bus.unsubscribe(CombatEvent.Type.ON_HIT, _on_hit)
	_bus = null

func take_damage(_amount: int) -> void:
	pass # This object responds to elements rather than health depletion.

func _on_hit(event: CombatEvent) -> void:
	if completed or event.target != self or not eligible():
		return
	var tags: Array = event.skill.tags if event.skill else event.data.get("tags", [])
	for i in range(_steps.size()):
		var route: PackedStringArray = spec.routes[i].steps
		if _steps[i] < route.size() and str(route[_steps[i]]) in tags:
			_steps[i] += 1
	_evaluate_routes(0.0)
	_refresh()

func tick(delta: float) -> void:
	if completed:
		_update_focus()
		return
	_evaluate_routes(delta)
	_refresh()

func _evaluate_routes(delta: float) -> void:
	if not eligible():
		for i in range(_steps.size()):
			_steps[i] = 0
			_held[i] = 0
		return
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager() if GameRuntime.instance else null
	for i in range(spec.routes.size()):
		var route := spec.routes[i]
		if _steps[i] < route.steps.size(): continue
		if not route.required_surface.is_empty():
			if not surfaces or surfaces.surface_at(global_position + route.surface_offset).get("state", "dry") != route.required_surface:
				_held[i] = 0.0
				continue
			_held[i] += delta
			if _held[i] + 0.000001 < route.hold_seconds: continue
		finish(route.id if not route.id.is_empty() else "spell_%d" % i)
		break

func eligible() -> bool:
	return not completed and (not eligibility.is_valid() or str(eligibility.call()).is_empty())

func finish(method_id: String) -> bool:
	if completed: return false
	if completion_handler.is_valid() and not completion_handler.call(method_id): return false
	completed = true
	set_deferred("collision_layer", 0)
	_refresh()
	solved.emit(spec)
	var director:=PresentationDirector.for_node(self)
	if director: director.emit_cue(&"puzzle",global_position,"puzzle:"+spec.id)
	return true

func _refresh() -> void:
	var count := 0
	for step in _steps:
		count = maxi(count, step)
	var result := " · 已解开" if spec.pickup_claim.is_empty() else " · 已取件" if part_taken else " · 可取件"
	_label.text = "[F] " + str(spec.title) + (result if completed else (" · 共鸣%d" % count if count > 0 else ""))
	if not completed:
		for i in range(spec.routes.size()):
			var route := spec.routes[i]
			if not route.required_surface.is_empty():
				_label.text += "\n%s保持 %.1f / %.1f秒" % [SurfaceManager.surface_title(route.required_surface), _held[i], route.hold_seconds]
	_update_focus()
	queue_redraw()

func _update_focus() -> void:
	if not world_art: return
	var player:=get_tree().get_first_node_in_group("player") as Player
	_label.visible=is_instance_valid(player) and player.input_controller.interaction_target()==self

func _draw() -> void:
	if not completed and (not world_art or _label.visible):
		for route in spec.routes:
			if route.required_surface.is_empty(): continue
			var corner := Vector2(SurfaceManager.cell_at(global_position + route.surface_offset)) * 64 - global_position
			draw_rect(Rect2(corner, Vector2(64,64)), Color(.5,.8,.9,.2))
			draw_rect(Rect2(corner, Vector2(64,64)), Color(.5,.8,.9,.7), false, 2)
	if world_art:
		if presentation and presentation.has_body_art(): return
		var tint:=GameUIStyle.SUCCESS if completed else GameUIStyle.GOLD
		if spec.id=="river.north_beacon":
			if _label.visible: draw_arc(Vector2.ZERO,38,0,TAU,32,tint,1,true)
			return
		draw_rect(Rect2(-23,-14,46,34),Color("262f2e"))
		draw_rect(Rect2(-23,-14,46,11),Color("6d7060"))
		draw_line(Vector2(-17,5),Vector2(17,5),Color("a69772"),2)
		draw_arc(Vector2(0,-5),10,0,TAU,24,tint,2,true)
		if _label.visible: draw_arc(Vector2.ZERO,29,0,TAU,32,tint,1,true)
		return
	var color := Color(0.4, 0.9, 0.65) if completed else Color(0.8, 0.6, 1.0)
	draw_circle(Vector2.ZERO, 23, Color(color, 0.18))
	draw_rect(Rect2(-18, -18, 36, 36), color, false, 2)
	draw_arc(Vector2.ZERO, 13, 0, TAU, 24, color, 2)
	if completed:
		draw_polyline(PackedVector2Array([Vector2(-9, 0), Vector2(-2, 8), Vector2(11, -8)]), color, 3)
