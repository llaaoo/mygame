extends "res://tests/support/input_scene_probe.gd"
## Controlled town stock/position fixture; real input with normal AI and simulation.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player
	var store:=game.session.inventory
	store.receive("player","river_sabre",1); store.receive("player","metal_scrap",8); store.receive("player","coin",60)
	var uid:=store.find_owned("player","river_sabre")
	actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
	await key(KEY_F,true); await key(KEY_F,false)
	check(is_instance_valid(game.ui.modal) and not paused,"F failed to open the live town workshop")
	await click("驿路短刀 ×1 · 8币")
	await click("强化 · 5币 + 2金属碎料")
	check(store.item(uid).properties.get("upgrade_level",0)==1,"Mouse upgrade did not modify the actual instance")
	await click("驿路短刀 +1 ×1 · 10币")
	await capture("depth-workshop")
	await click("出售一件 · 10币")
	check(store.locate(uid)==TownServices.MERCHANT+".pack","Mouse sale lost the selected UID")
	await click("购买实物")
	await click("驿路短刀 +1 ×1 · 20币")
	await click("购买一件 · 20币")
	check(store.locate(uid)=="player.pack" and store.item(uid).properties.upgrade_level==1,"Mouse buy changed upgrade identity")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	# Teaching, binding and using E are ordinary UI/input operations.
	var npc:=game.session.actor_for_id("river.enemy.service.trainer") as ServiceNPC
	actor.position=npc.position+Vector2(0,40); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
	await key(KEY_F,true); await key(KEY_F,false)
	await click("学习武技")
	await click("破势斩 · 8币")
	check(actor.actor_context.martial.learned.has("blade_breaker"),"Trainer mouse service did not unlock martial knowledge")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	store.equip("player",uid)
	await key(KEY_K,true); await key(KEY_K,false)
	await click("武技"); await click("破势斩 · 已学")
	check(actor.actor_context.martial.route_slots("blade:light/heavy").size()==2,"Training did not equip the bounded combo loadout")
	await capture("depth-martial-binder")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
	await frames(5); await aim_world(actor.position+Vector2(150,0))
	var mp:=actor.mana_component.mp
	var attacks:=actor.actor_context.actions._attack_sequence
	await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false)
	await create_timer(1.0).timeout
	await pointer_button(MOUSE_BUTTON_LEFT,true); await create_timer(.37).timeout; await pointer_button(MOUSE_BUTTON_LEFT,false)
	for i in range(130):
		if actor.actor_context.actions.mode=="idle": break
		await frames(1)
	await key(KEY_CTRL,true); await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false); await key(KEY_CTRL,false)
	check(actor.actor_context.actions._attack_sequence==attacks+3 and actor.mana_component.mp==mp,"Combo did not execute exactly one earned physical technique without MP")
	await create_timer(1.5).timeout
	# Rest is selected by mouse and advances the persistent world clock on completion.
	var rest: ExplorationInteractable
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.get_meta("survival_rest",false): rest=node
	store.receive("player","ration",4); store.receive("player","clean_water",4)
	actor.position=rest.position+Vector2(0,30); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
	await key(KEY_F,true); await key(KEY_F,false)
	var work:=actor.field_work
	check(work.panel.visible and not paused,"Rest did not expose live hour selection")
	await capture("depth-rest-hours")
	await point_click(work.panel.start_button.get_global_rect().get_center())
	check(work.is_busy(),"Mouse rest did not start interruptible preparation")
	var before:=store.clock_seconds
	await create_timer(3.0).timeout
	check(store.clock_seconds-before>60 and store.clock_seconds-before<65 and not work.is_busy(),"One-hour rest did not advance the shared clock once")
	await capture("depth-rest-complete")
	# Potion is a real item shortcut, separate from the learned martial E binding.
	store.receive("player","guard_tonic",1)
	actor.skill_manager.shortcuts.bind_item("slot_0","guard_tonic")
	await key(KEY_1,true); await key(KEY_1,false); await create_timer(1.3).timeout
	check(actor.get_node("BuffManager").has_buff("guard_tonic") and store.count("player","guard_tonic")==0,"1 did not consume the real potion through normal timed input")
	check(actor.actor_context.martial.route_equipped("blade_breaker","power"),"Potion shortcut replaced combo equipment")
	await capture("depth-provisions")
	# A bow bought through the service uses LMB, actual arrows and no spell mana.
	actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
	await key(KEY_F,true); await key(KEY_F,false)
	await click("购买实物"); await click("河谷猎弓 ×1 · 20币"); await click("购买一件 · 20币")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	var bow_uid:=store.find_owned("player","river_bow")
	check(not bow_uid.is_empty() and store.equip("player",bow_uid).accepted,"Purchased bow could not equip its actual instance")
	store.receive_into("player.pocket","arrow",2)
	await frames(8)
	var ammunition:=store.count("player","arrow")
	mp=actor.mana_component.mp
	var sequence:=actor.actor_context.actions._attack_sequence
	var point:=Vector2(710,320)
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
	Input.parse_input_event(motion); await frames(2)
	var press:=InputEventMouseButton.new(); press.position=point; press.global_position=point; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
	Input.parse_input_event(press); await frames(2)
	press=press.duplicate(); press.pressed=false; Input.parse_input_event(press)
	await create_timer(.7).timeout
	check(actor.actor_context.actions._attack_sequence==sequence+1 and store.count("player","arrow")==ammunition-1 and actor.mana_component.mp==mp,"Real LMB did not fire exactly one actual arrow without MP")
	await capture("depth-bow")
	await fixture.close()
	if failures.is_empty(): print("PASS depth input: F workshop, mouse UID upgrade/sell/buy, trainer, K martial loadout, independent item slots, hourly rest, potion and LMB bow; normal AI/simulation, controlled stock and positions")
	quit(0 if failures.is_empty() else 1)
