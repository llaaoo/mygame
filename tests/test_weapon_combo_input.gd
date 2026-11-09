extends "res://tests/support/input_scene_probe.gd"
## Normal AI, clocks and budgets; equipment and safe position are controlled.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var starts: Array[Dictionary]=[]
func aim(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new(); event.position=root.get_canvas_transform()*point; event.global_position=event.position
	if DisplayServer.get_name()!="headless": Input.warp_mouse(event.position)
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames(1)
func mouse(held: bool) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=held; event.position=root.get_mouse_position(); event.global_position=event.position
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames(1)
func press() -> void: await mouse(true); await mouse(false)
func wait_idle() -> void:
	for i in range(180):
		if game.player.actor_context.actions.mode=="idle": return
		await frames(1)
	check(false,"Physical stroke never completed")
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player; var actions:=actor.actor_context.actions; var store:=game.session.inventory
	actor.health_component.regen_rate=.6; actor.mana_component.mp_regen_rate=3
	actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
	store.receive_into("player.pocket","arrow",4)
	for id in ["river_sabre","river_spear","river_staff","river_bow"]: store.receive("player",id,1)
	game.session.facts.committed.connect(func(fact: Dictionary):
		if fact.kind=="physical_action_started" and fact.source=="player": starts.append(fact.data.duplicate(true)))
	for id in ["river_sabre","river_spear","river_staff","river_bow"]:
		store.equip("player",store.find_owned("player",id))
		for i in range(600):
			if actions.stamina.current>=95: break
			await frames(1)
		check(actions.stamina.current>=95,"Ordinary rest did not restore enough stamina for the next weapon")
		await aim(actor.position+Vector2(150,0))
		var moves:=store.equipment_definition(str(store.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)])).moveset
		var before:=starts.size(); var arrows:=store.count("player","arrow")
		await press()
		for index in range(moves.attacks.size()):
			check(actions.mode=="attack" and actions.combo.current_index==index and starts.size()==before+index+1,"Real mouse did not select the expected stage: %s/%d"%[id,index])
			check(starts.back().stroke_title==moves.attacks[index].title,"HUD/action facts disagree with the real stroke")
			if index==moves.attacks.size()-1:
				await capture("combo-"+moves.weapon_type)
				await wait_idle()
			else:
				for i in range(120):
					if actions.remaining<=.22: break
					await frames(1)
				await press()
				check(not actions.buffered_action_label().is_empty(),"Manual continuation did not enter the short buffer")
				for i in range(60):
					if starts.size()==before+index+2: break
					await frames(1)
		await frames(8)
		check(actions.combo_snapshot().is_empty() and actions.mode=="idle" and starts.size()==before+moves.attacks.size(),"Finisher restarted without another mouse press")
		check(store.count("player","arrow")==arrows-(2 if moves.weapon_type=="bow" else 0),"Bow continuation did not spend one arrow per manual shot")
		print("COMBO_INPUT ",JSON.stringify({"weapon":moves.weapon_type,"strokes":starts.slice(before),"stamina":actions.stamina.current,"arrows":store.count("player","arrow"),"mp":actor.mana_component.mp}))
	# A live interface clears continuation; closing it cannot release a ghost press.
	store.equip("player",store.find_owned("player","river_sabre"))
	await aim(actor.position+Vector2(150,0)); await press(); await wait_idle()
	check(not actions.combo_snapshot().is_empty(),"No continuation window after first stroke")
	await key(KEY_I,true); await key(KEY_I,false)
	check(actions.combo_snapshot().is_empty() and not paused,"Real inventory input preserved combo or paused the world")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	var before:=starts.size(); await press()
	check(starts.size()==before+1 and starts.back().stroke_index==0,"Closing interface replayed or continued an old chain")
	await wait_idle()
	var uid:=str(store.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)]); var arrows:=store.count("player","arrow")
	await key(KEY_F5,true); await key(KEY_F5,false)
	await key(KEY_F9,true); await key(KEY_F9,false)
	check(actions.combo_snapshot().is_empty() and str(store.equipped("player")[str(EquipmentData.SlotType.RIGHT_HAND)])==uid and store.count("player","arrow")==arrows,"Real restore retained transient combo or changed UID/ammo")
	check(game.active_enemies.all(func(foe): return foe.can_process()) and actor.mana_component.mp==60,"Normal simulation or physical mana budget changed")
	await fixture.close()
	if failures.is_empty(): print("PASS weapon combo input: four full real-mouse buffered chains, per-stroke HUD/facts, natural stamina recovery, real arrows, live menu cancellation and F5/F9 UID/ammo persistence without chain")
	quit(0 if failures.is_empty() else 1)
