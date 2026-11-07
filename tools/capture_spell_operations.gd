extends SceneTree
## Staged UI/input probe with normal simulation and AI. Supplies are deliberately
## granted for inspection; this is not a natural resource-budget playthrough.
var game: GrayriverGame
var output:="/tmp/material-operations-visual"
var failures: Array[String]=[]
var casts: Array[String]=[]
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func settle(n:=8) -> void:
	for i in range(n): await process_frame
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func click_button(label: String) -> void:
	var button: Button
	for node in root.find_children("*","Button",true,false):
		if node is Button and node.text==label and node.is_visible_in_tree(): button=node; break
	check(button!=null,"Could not find actual UI button: "+label)
	if not button: return
	var point:=button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"Payload choice is outside viewport")
	var motion:=InputEventMouseMotion.new(); motion.position=point; Input.parse_input_event(motion)
	await settle(2)
	var press:=InputEventMouseButton.new(); press.position=point; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
	Input.parse_input_event(press); await settle(2)
	press=press.duplicate(); press.pressed=false; Input.parse_input_event(press)
	await settle()
func run() -> void:
	game=load("res://grayriver.tscn").instantiate(); game.persistence_enabled=false
	root.add_child(game); current_scene=game
	await settle(35); game.ui.close_modal()
	game.progress.actions.merge({"fire_sigil":true,"frost_sigil":true,"water_call":true})
	game._apply_knowledge()
	var sm:=game.player.skill_manager
	var supplies:=sm.combinations.supplies
	supplies.grant({"fire_stone":2,"venom_extract":2,"paralytic_extract":1,"clean_water":2})
	var rune:=sm.pool.get_skill("inscribe")
	game.workshop.show_action(rune)
	await capture("inscription")
	await click_button("选择：火石阵")
	check(supplies.selected.get("inscribe")=="ember","Actual pointer click failed to select fire stone")
	check(root.gui_get_focus_owner()!=null and "火石阵" in root.gui_get_focus_owner().text,"Keyboard focus did not follow selected payload")
	check(supplies.count("fire_stone")==2,"Material selection consumed a stone before casting")
	root.content_scale_size=Vector2i(960,600); root.size=Vector2i(960,600)
	game.workshop.show_action(sm.pool.get_skill("disperse"))
	await capture("spray-small")
	await click_button("选择：麻痹喷洒")
	check(supplies.selected.get("disperse")=="paralytic","Small-window pointer selection failed")
	check(sm.combinations.preview(sm.pool.get_skill("disperse"),game.player).skill.contact_statuses[0].prevents_actions,"UI selection did not reach the real execution plan")
	game.ui.close_modal()
	game.hub.open("supplies"); game.hub._select("paralytic_extract")
	await capture("reagent-inventory-small")
	game.ui.close_modal()
	check(GameRuntime.instance.is_processing() and not paused,"Probe disabled the world simulation")
	game.player.position=Vector2(-3500,2000)
	game.player.get_node("Camera2D").reset_smoothing()
	sm.equip_slot(4,sm.pool.get_skill("disperse"))
	sm.cast_committed.connect(func(plan: CastPlan): casts.append(plan.skill.get_id()))
	ControlPreferences.set_quick_cast(true)
	var motion:=InputEventMouseMotion.new(); motion.position=Vector2(580,300); Input.parse_input_event(motion)
	await physics_frame
	Input.action_press("skill_5")
	await physics_frame
	await physics_frame
	Input.action_release("skill_5")
	await create_timer(.55).timeout
	check(casts.has("disperse.paralytic") and supplies.count("paralytic_extract")==0,"Actual shortcut did not cast and consume the selected reagent in the running world")
	await capture("spray-release")
	game.ui.close_modal(); game.queue_free(); current_scene=null
	await settle()
	if failures.is_empty(): print("PASS material operation graphics: real pointer choices, unchanged counts, small-window payload selection and authoritative plan")
	quit(0 if failures.is_empty() else 1)
