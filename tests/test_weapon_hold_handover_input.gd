extends "res://tests/support/input_scene_probe.gd"
## Actual input ownership across items and weapon holds, with live simulation/AI.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var starts := 0
func seconds(duration: float) -> void:
	var until:=game.player.actor_context.actions.weapon_art.clock+duration
	while game.player.actor_context.actions.weapon_art.clock<until: await frames(1)
func click_left() -> void:
	await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false)
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot()
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player; var c:=actor.actor_context; var store:=game.session.inventory; var manager:=actor.skill_manager
	actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
	store.receive("player","river_sabre",1); store.equip("player",store.find_owned("player","river_sabre"))
	store.receive_into("player.pocket","fire_rag",1); store.receive_into("player.pocket","venom_bottle",1); store.receive_into("player.pocket","water_sprayer",1)
	game.session.facts.committed.connect(func(fact: Dictionary):
		if fact.kind=="physical_action_started" and fact.source=="player": starts+=1)
	await frames(12); await aim_world(actor.position+Vector2(150,0))
	manager.shortcuts.bind_item("quick_e","fire_rag")
	await key(KEY_E,true); await key(KEY_E,false)
	check(c.item_actions.busy() and c.actions.mode=="item","Real rag input did not start preparation")
	await click_left(); await seconds(.8)
	check(starts==1 and not c.item_actions.busy() and store.count("player","fire_rag")==1,"Attack gesture failed to cancel unpaid item preparation")
	manager.shortcuts.bind_item("quick_e","venom_bottle")
	await key(KEY_E,true)
	check(c.item_actions.aiming,"Actual item shortcut did not aim the throw")
	await click_left(); await key(KEY_E,false); await seconds(1)
	check(starts==1 and store.count("player","venom_bottle")==0 and c.actions.weapon_hold_view().is_empty(),"Mouse-confirmed throw was cancelled or also produced a weapon strike")
	manager.known_actions.disperse=true
	var bottle:=store.ready_uid("player","water_sprayer")
	manager.shortcuts.bind_item("quick_e","water_sprayer",bottle)
	await key(KEY_E,true); await seconds(.3)
	check(c.spray.active,"Actual bottle shortcut did not start spraying")
	var doses:=int(store.item(bottle).properties.doses)
	check(doses<3,"Real spray did not pay its first pulse")
	await click_left(); await key(KEY_E,false); await seconds(.8)
	check(starts==2 and not c.spray.active and int(store.item(bottle).properties.doses)==doses,"Attack failed to stop spray, refunded it or leaked another pulse")
	check(not paused and game.active_enemies.all(func(enemy): return enemy.can_process()),"Handover probe disabled world/AI")
	await fixture.close()
	if failures.is_empty(): print("PASS weapon hold handover input: real rag cancellation without payment, left-confirmed physical throw without ghost attack, spray-to-strike retaining paid doses; normal AI at safe fixture position")
	quit(0 if failures.is_empty() else 1)
