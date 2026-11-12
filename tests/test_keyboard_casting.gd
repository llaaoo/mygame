extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
var casts:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=4) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func key(code: Key,held: bool) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=held
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames()
func mouse(button: MouseButton,held: bool) -> void:
	if DisplayServer.get_name()!="headless": Input.warp_mouse(Vector2(621,324))
	var event:=InputEventMouseButton.new(); event.position=Vector2(621,324); event.global_position=event.position; event.button_index=button; event.pressed=held
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames()
func point_click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	root.push_input(motion,true); Input.flush_buffered_events(); await frames()
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	root.push_input(event,true); Input.flush_buffered_events(); await frames()
	event=event.duplicate(); event.pressed=false; root.push_input(event,true); await frames()

func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot()
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	var actor:=game.player
	var manager:=actor.skill_manager
	var store:=game.session.inventory
	GameRuntime.instance.set_process(true)
	actor.position=Vector2(-3500,2000); actor.get_node("Camera2D").reset_smoothing()
	manager.restrict_actions=false
	manager.equip_hand("left",manager.pool.get_skill("ignite")); manager.equip_hand("right",manager.pool.get_skill("ignite"))
	manager.cast_committed.connect(func(_plan): casts+=1)
	store.receive("player","river_sabre",1); store.equip("player",store.find_owned("player","river_sabre"))
	var target:=game.active_enemies[0]; target.position=actor.position+Vector2(45,0); target.health_component.invincible=false
	target.process_mode=Node.PROCESS_MODE_INHERIT; target.set_physics_process(false)
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.actor_context.actions.set_physics_process(false)
	var motion:=InputEventMouseMotion.new(); motion.position=Vector2(621,324); motion.global_position=motion.position
	if DisplayServer.get_name()!="headless": Input.warp_mouse(motion.position)
	Input.parse_input_event(motion); Input.flush_buffered_events(); await frames()
	var mp:=actor.mana_component.mp
	await mouse(MOUSE_BUTTON_RIGHT,true)
	check(actor.actor_context.actions.guarding and casts==0 and actor.mana_component.mp==mp,"Right mouse cast a spell or failed to guard with a real weapon")
	await mouse(MOUSE_BUTTON_RIGHT,false)
	check(not actor.actor_context.actions.guarding,"Releasing right mouse left guard stuck")
	var hp:=target.health_component.hp
	await mouse(MOUSE_BUTTON_LEFT,true); await mouse(MOUSE_BUTTON_LEFT,false); await frames(25)
	check(target.health_component.hp<hp and casts==0 and actor.mana_component.mp==mp,"Left mouse with an equipped legacy left slot did not remain a weapon attack")
	await key(KEY_R,true); await key(KEY_R,false); await frames(25)
	check(casts==1 and actor.mana_component.mp==mp-4,"Independent R key did not commit the spell")
	manager.combinations.cooldowns.clear(); manager.combinations._recovery=0
	var project:=manager.pool.get_skill("project")
	root.size=Vector2i(960,600); await frames()
	await key(KEY_K,true); await key(KEY_K,false)
	var pool: SkillPoolUI=actor.skill_pool_ui
	var card: PanelContainer
	for node in pool._skill_grid.get_children():
		for label in node.find_children("*","Label",true,false):
			if label.text==project.display_name: card=node
	check(card!=null,"New operation is absent from the real K loadout")
	if card:
		var parent:=card.get_parent()
		while parent:
			if parent is ScrollContainer: parent.ensure_control_visible(card)
			parent=parent.get_parent()
		await frames()
		await point_click(card.get_global_rect().position+Vector2(card.size.x*.5,20))
		var ancestor:=pool._equip_slots[0].get_parent()
		while ancestor:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(pool._equip_slots[0])
			ancestor=ancestor.get_parent()
		await frames()
		await point_click(pool._equip_slots[0].get_global_rect().get_center())
	check(manager.left_hand and manager.left_hand.data.get_id()=="project","Clicking the operation icon and Q slot failed to equip")
	var last:=pool._equip_slots.back() as Control
	var binding_parent:=last.get_parent()
	while binding_parent and not binding_parent is ScrollContainer: binding_parent=binding_parent.get_parent()
	var scroll:=binding_parent as ScrollContainer
	scroll.ensure_control_visible(last); await frames()
	check(root.get_visible_rect().encloses(last.get_global_rect()),"Small-window K leaves the sixth keyboard slot unreachable")
	var visual:=OS.get_environment("LEGACY_CAST_VISUAL_OUTPUT")
	if not visual.is_empty() and DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute(visual)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(visual.path_join("keyboard-small-window.png"))
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(not paused and not actor.ui_blocked,"Closing K opened an unrelated pause menu or left input blocked")
	store.receive("player","fire_stone",2)
	manager.combinations.supplies.select_payload(project,"charged_fireball",manager)
	var rune:=FireSigil.new(); rune.caster=actor; rune.field_type="fire"; rune.charges=2
	game.region_root.add_child(rune); rune.position=actor.position; manager.combinations.fields.append(rune)
	mp=actor.mana_component.mp
	await key(KEY_Q,true); await frames(10)
	check(actor.casting._charging_source=="left","Q did not begin charge")
	await mouse(MOUSE_BUTTON_RIGHT,true)
	check(actor.casting._charging_source.is_empty() and actor.actor_context.actions.guarding,"Right guard did not cancel keyboard charge")
	await key(KEY_Q,false); await mouse(MOUSE_BUTTON_RIGHT,false); await frames(25)
	check(casts==1 and actor.mana_component.mp==mp and store.count("player","fire_stone")==2 and rune.charges==2,"Cancelled charge leaked a release or spent a source")
	manager.equip_slot(5,manager.pool.get_skill("sustain")); await frames(12)
	var bar: SkillBar=game.get_node("HUDLayer").skill_bar
	check(bar._cost_labels[bar._sources.find("slot_5")].text=="5/次","Channel HUD still advertises zero MP instead of per-pulse mana")
	await fixture.close()
	if failures.is_empty(): print("PASS keyboard casting: fixed mouse attack/guard, real R spell, Q charge, guard cancel without release or payment")
	quit(0 if failures.is_empty() else 1)
