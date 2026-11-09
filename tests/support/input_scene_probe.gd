extends SceneTree
var failures: Array[String]=[]
var game: GrayriverGame
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=4) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func key(code: Key,held: bool,unicode_value:=0) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=held; event.unicode=unicode_value
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames()
func aim_world(point: Vector2) -> void:
	# Input.parse_input_event consumes window pixels. Headless windows may be 64²
	# while the logical game canvas is 1152×648; preserve stretch and letterboxing.
	var event:=InputEventMouseMotion.new()
	event.position=root.get_screen_transform()*root.get_canvas_transform()*point
	event.global_position=event.position
	if DisplayServer.get_name()!="headless": Input.warp_mouse(event.position)
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames(1)
func pointer_button(button: MouseButton,held: bool) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=button; event.pressed=held
	event.position=root.get_screen_transform()*root.get_mouse_position(); event.global_position=event.position
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames(1)
func point_click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	root.push_input(motion,true); Input.flush_buffered_events(); await frames()
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	root.push_input(event,true); Input.flush_buffered_events(); await frames()
	event=event.duplicate(); event.pressed=false; root.push_input(event,true); await frames()
func click(text: String) -> void:
	var found: Button
	for node in root.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and (node.text==text or node.text.begins_with(text+"\n")): found=node; break
	check(found!=null,"Missing visible button: "+text)
	if not found: return
	var ancestor:=found.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(found)
		ancestor=ancestor.get_parent()
	await frames()
	await point_click(found.get_global_rect().get_center())
func capture(name: String) -> void:
	var output:=OS.get_environment("CONTROLS_VISUAL_OUTPUT")
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func run() -> void: pass
