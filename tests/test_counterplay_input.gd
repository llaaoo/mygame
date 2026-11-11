extends "res://tests/support/input_scene_probe.gd"
## Controlled stock/geometry, live simulation; all combo actions use real keys.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var outcomes: Array[Dictionary]=[]
func aim_at(point: Vector2) -> void:
	var screen:=root.get_canvas_transform()*point
	if DisplayServer.get_name()!="headless": Input.warp_mouse(screen)
	var event:=InputEventMouseMotion.new(); event.position=screen; event.global_position=screen
	Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	var actor:=game.player
	check(preload("res://tests/support/awakened_actor_fixture.gd").awaken(actor),"Controlled counterplay caster could not awaken")
	var stock:=game.session.inventory
	var manager:=actor.skill_manager
	var base:=Vector2(-4000,800)
	actor.position=base+Vector2(192,0)
	actor.get_node("Camera2D").reset_smoothing()
	stock.receive("player","resin_sprayer",1); stock.receive("player","river_staff",1)
	stock.equip("player",stock.find_owned("player","river_staff"))
	var bottle:=stock.find_owned("player","resin_sprayer")
	game.progress.actions["disperse"]=true; game.progress.actions["ignite"]=true; game._apply_knowledge()
	manager.equip_source("left",manager.pool.get_skill("disperse"))
	check(QuickslotMaterials.select(actor,"left",{"payload":"resin","uid":bottle,"modifier":""}),"Fixed real resin bottle could not be selected")
	manager.equip_source("slot_0",manager.pool.get_skill("ignite"))
	actor.actor_context.martial.learn("staff_sweep")
	# No fake damage, costs, surface creation, or direct skill calls in this sequence.
	GameRuntime.instance.set_process(true)
	await frames(6); aim_at(actor.position+Vector2(200,0))
	var mp:=actor.mana_component.mp
	await key(KEY_Q,true); await create_timer(.3).timeout; await key(KEY_Q,false)
	check(stock.item(bottle)!=null and int(stock.item(bottle).properties.doses)==2 and actor.mana_component.mp==mp,"Real Q did not commit exactly one ordinary resin dose at zero MP")
	var surfaces:=SurfaceManager.instance
	check(surfaces.surface_at(base+Vector2(192,0)).state=="oiled","Real spray failed to create the target oil cell")
	await capture("counterplay-oil-preparation")
	await key(KEY_1,true); await key(KEY_1,false); await create_timer(.4).timeout
	check(actor.mana_component.mp==mp-4 and surfaces.surface_at(base+Vector2(128,0)).state=="burning","Real 1 did not turn the prepared oil into fire for 4 MP")
	# Earn the sweep with real light/heavy strokes away from the delivery target.
	actor.position=base; actor.get_node("Camera2D").reset_smoothing()
	await aim_world(base+Vector2(0,-150))
	await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false)
	await create_timer(1.0).timeout
	await pointer_button(MOUSE_BUTTON_LEFT,true); await create_timer(.37).timeout; await pointer_button(MOUSE_BUTTON_LEFT,false)
	for i in range(130):
		if actor.actor_context.actions.mode=="idle": break
		await frames(1)
	# Reposition the controlled fixture to demonstrate physical delivery into that
	# same cell. Enemy decisions are disabled here; its physics/statuses remain live.
	actor.position=base; actor.get_node("Camera2D").reset_smoothing()
	var target:=game.active_enemies[0]
	target.position=base+Vector2(40,0)
	target.process_mode=Node.PROCESS_MODE_INHERIT
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.set_process(false)
	var observer:=func(receiver: Node2D,outcome: Dictionary):
		if receiver==target: outcomes.append(outcome.duplicate())
	CombatExecutor.instance.defense_resolved.connect(observer)
	check(surfaces.surface_at(target.position).state=="dry","Delivery fixture did not start on safe ground")
	await frames(5); aim_at(target.position)
	await key(KEY_CTRL,true); await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false); await key(KEY_CTRL,false)
	await create_timer(.2).timeout; await capture("counterplay-heavy-warning")
	await create_timer(.65).timeout
	check(outcomes.any(func(outcome): return outcome.get("pushed",false)),"Real combo sweep produced no qualified physical push")
	check(target.position.x>base.x+90 and surfaces.surface_at(target.position).state=="burning","Sweep did not carry the target into the player-created fire")
	var hp:=target.health_component.hp
	await capture("counterplay-delivered-into-fire")
	# Surface exposure is sampled every .5s, then burning needs its own 1s tick.
	# Observe the real outcome within 2s rather than assuming a favourable tick phase.
	for i in range(120):
		if target.health_component.hp<hp: break
		await frames(1)
	check(target.health_component.hp<hp,"Player-created ground hazard produced no real periodic damage after push")
	check(stock.item(bottle)!=null and int(stock.item(bottle).properties.doses)==2 and not paused,"Physical delivery consumed an extra dose or paused the world")
	CombatExecutor.instance.defense_resolved.disconnect(observer)
	print("Counterplay input measurement: "+JSON.stringify({"kind":"controlled stock and staged geometry; enemy decisions disabled, live physics/statuses","mp_before":mp,"mp_after":actor.mana_component.mp,"doses_remaining":stock.item(bottle).properties.doses,"push_x":target.position.x-base.x,"hazard_hp_before":hp,"hazard_hp_after":target.health_component.hp,"outcomes":outcomes}))
	actor.actor_context.actions.interrupt(.3)
	game._save_progress()
	await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	stock=game.session.inventory
	check(stock.item(bottle)!=null and int(stock.item(bottle).properties.doses)==2,"Actual save/reentry refilled or replaced the selected bottle")
	check(game.player.actor_context.actions.mode=="idle" and game.player.actor_context.actions.push_recovery==0,"Reentry restored transient combat control")
	check(game.player.actor_context.martial.route_equipped("staff_sweep","power"),"Reentry lost the martial route loadout")
	await fixture.close()
	if failures.is_empty(): print("PASS counterplay input: real Q resin, 1 ignition, combo sweep into created fire, real DOT, resource identity and save/reentry")
	quit(0 if failures.is_empty() else 1)
