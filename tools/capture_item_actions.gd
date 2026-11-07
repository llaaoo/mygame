extends SceneTree
## Staged graphical/input probe with normal simulation and AI, not a budget playthrough.
var game: GrayriverGame
var output:="/tmp/item-actions-visual"
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
func key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event); await settle(2)
func click_button(label: String) -> void:
	var button: Button
	for node in root.find_children("*","Button",true,false):
		if node is Button and node.text==label and node.is_visible_in_tree(): button=node; break
	check(button!=null,"Missing actual UI button: "+label)
	if not button: return
	var ancestor:=button.get_parent()
	while ancestor:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle()
	button.grab_focus()
	await settle()
	var point:=button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"UI choice is outside viewport")
	var motion:=InputEventMouseMotion.new(); motion.position=point; Input.parse_input_event(motion)
	await settle(2)
	var event:=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); await settle(2)
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); await settle()
func run() -> void:
	game=load("res://grayriver.tscn").instantiate(); game.persistence_enabled=false
	root.add_child(game); current_scene=game
	await settle(35); game.ui.close_modal()
	game.progress.actions.merge({"fire_sigil":true,"venom_mist":true,"focus":true,"soul_harvest":true})
	game._apply_knowledge()
	var actor:=game.player
	actor.position=Vector2(-3500,2000); actor.get_node("Camera2D").reset_smoothing()
	var sm:=actor.skill_manager
	var supplies:=sm.combinations.supplies
	var store:=game.session.inventory
	check(actor.actor_context.spray.global_position.distance_to(actor.global_position)<.1 and actor.actor_context.item_actions.global_position.distance_to(actor.global_position)<.1,"Spatial action components lost their actor transform")
	store.receive("player","river_sabre",1); store.equip("player",store.find_owned("player","river_sabre"))
	store.receive("player","poison_rag",2); store.receive("player","venom_bottle",2); store.receive("player","venom_sprayer",2)
	store.receive("player","fire_stone",2)
	game.hub.open("supplies"); game.hub._select("poison_rag")
	await click_button("涂附当前主手武器")
	await create_timer(1.35).timeout
	var weapon:=str(store.equipped("player").get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	check(store.coating(weapon)!=null and store.count("player","poison_rag")==1,"Actual coating button failed to apply one rag to the equipped weapon")
	game.hub.open("equipment"); game.hub._select("uid:"+weapon)
	await capture("coated-weapon")
	var clock:=store.clock_seconds
	await create_timer(.15,true).timeout
	check(store.clock_seconds==clock,"Paused equipment menu decayed a weapon coating")
	game.ui.close_modal(); game.session.bind_belt(0,"venom_bottle","throw")
	var motion:=InputEventMouseMotion.new(); motion.position=Vector2(750,320); Input.parse_input_event(motion)
	sm.cast_committed.connect(func(plan: CastPlan): casts.append(plan.skill.get_id()))
	await key(KEY_7,true)
	check(actor.actor_context.item_actions.aiming,"Holding item shortcut failed to enter aim")
	await capture("throw-aim")
	var cancel_event:=InputEventMouseButton.new(); cancel_event.position=Vector2(750,320); cancel_event.button_index=MOUSE_BUTTON_RIGHT; cancel_event.pressed=true
	Input.parse_input_event(cancel_event); await settle(3)
	cancel_event=cancel_event.duplicate(); cancel_event.pressed=false; Input.parse_input_event(cancel_event)
	await key(KEY_7,false)
	check(not actor.actor_context.item_actions.busy() and store.count("player","venom_bottle")==2 and casts.is_empty(),"Right-click cancellation consumed a bottle or fired a spell")
	await key(KEY_7,true); await key(KEY_7,false)
	await create_timer(.65).timeout
	check(store.count("player","venom_bottle")==1,"Releasing the item shortcut failed to launch a real bottle")
	await create_timer(.5).timeout
	root.content_scale_size=Vector2i(960,600); root.size=Vector2i(960,600)
	var uid:=store.ready_uid("player","venom_sprayer")
	store.spend_instance("player",uid,"doses",1)
	game.hub.open("supplies"); game.hub._select("uid:"+uid)
	await capture("partial-bottle-small")
	await click_button("装填这瓶喷剂")
	check(supplies.prepared_uids.get("disperse")==uid,"Pointer selection ignored the chosen partial bottle")
	game.ui.close_modal(); sm.equip_slot(4,sm.pool.get_skill("disperse"))
	ControlPreferences.set_quick_cast(true)
	motion=InputEventMouseMotion.new(); motion.position=Vector2(660,300); Input.parse_input_event(motion)
	await key(KEY_5,true)
	await create_timer(.3).timeout
	check(actor.actor_context.spray.active and store.item(uid).properties.doses==1,"Held spray key failed to consume one dose from the selected bottle")
	await capture("spray-cone")
	await key(KEY_5,false)
	await create_timer(.2).timeout
	check(not actor.actor_context.spray.active and store.item(uid).properties.doses==1,"Key release did not stop the spray")
	game.workshop.show_action(sm.pool.get_skill("focus"))
	await click_button("选择：火阵调谐")
	check(supplies.selected.get("focus")=="attune_fire","Small-window explicit source choice failed")
	await capture("attunement-small")
	game.ui.close_modal()
	check(GameRuntime.instance.is_processing() and not paused,"Probe disabled simulation")
	game.queue_free(); current_scene=null; await settle()
	if failures.is_empty(): print("PASS item graphics: real pointer coating, paused lifetime, keyboard aim/cancel/throw, partial bottle selection, held cone spray/release and 960x600 source choice")
	quit(0 if failures.is_empty() else 1)
