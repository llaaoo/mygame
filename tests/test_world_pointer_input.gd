extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
var pointer_position:=Vector2.ZERO
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=4) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func pointer(point: Vector2) -> void:
	pointer_position=point
	if DisplayServer.get_name()!="headless": Input.warp_mouse(point)
	var event:=InputEventMouseMotion.new(); event.position=point; event.global_position=point; Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames()
func left_click() -> void:
	var event:=InputEventMouseButton.new(); event.position=pointer_position; event.global_position=pointer_position; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames(2)
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events(); await frames(2)
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot()
	var actor:=game.player
	actor.position=Vector2(-3500,2000); actor.get_node("Camera2D").reset_smoothing()
	var target:=game.active_enemies[0]
	target.position=actor.position+Vector2(45,0)
	target.process_mode=Node.PROCESS_MODE_INHERIT; target.set_physics_process(false)
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.actor_context.actions.set_physics_process(false)
	target.health_component.invincible=false
	await frames()
	await pointer(root.get_canvas_transform()*target.global_position)
	check(not actor.input_controller._pointer_over_interface(),"A fullscreen HUD container blocks world pointer input")
	var hp:=target.health_component.hp
	await left_click(); await frames(20)
	check(target.health_component.hp<hp and actor.actor_context.actions.stamina.current<100,"Real left-click failed to hit and pay for a physical attack through the passive HUD")
	await frames(35)
	hp=target.health_component.hp
	var sequence:=actor.actor_context.actions._attack_sequence
	await pointer(game.frontier_hud.tracker.get_global_rect().get_center())
	await left_click()
	check(is_instance_valid(game.ui.modal) and paused,"Real HUD button no longer receives pointer input")
	check(target.health_component.hp==hp and actor.actor_context.actions._attack_sequence==sequence,"Clicking the HUD also attacked a world target")
	# Input.parse_input_event updates the global Input state as an OS event would.
	# Exercise the new nonmodal controls through that path too (not only GUI dispatch).
	game.ui.close_modal(); await frames(15)
	var bench: ExplorationInteractable
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.callback==game.workshop.show_crafts: bench=node; break
	check(bench!=null,"Town workbench missing")
	if bench:
		actor.position=bench.position+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(15)
		sequence=actor.actor_context.actions._attack_sequence
		await pointer(game.frontier_hud.interact.get_global_rect().get_center()); await left_click()
		check(paused and is_instance_valid(game.ui.modal),"Global mouse input did not activate nearby interaction")
		check(actor.actor_context.actions._attack_sequence==sequence,"Nearby interaction mouse click leaked a weapon attack")
		game.ui.close_modal(); await frames(15)
	game.survival.supplies.grant({"ration":1})
	await frames(15)
	sequence=actor.actor_context.actions._attack_sequence
	await pointer(game.frontier_hud.belt[0].get_global_rect().get_center()); await left_click()
	check(actor.field_work.is_busy(),"Global mouse input did not activate supply belt")
	check(actor.actor_context.actions._attack_sequence==sequence,"Supply belt mouse click leaked a weapon attack")
	actor.field_work.cancel("test"); actor.field_work.close_panel()
	check(game.player.quest_manager==null and game.get_node_or_null("RunManager")==null,"Campaign still instantiates unused legacy quest/run owners")
	await fixture.close()
	if failures.is_empty(): print("PASS world pointer input: passive HUD passes melee, nearby and belt controls receive global mouse input without melee, campaigns keep one quest/run owner")
	quit(0 if failures.is_empty() else 1)
