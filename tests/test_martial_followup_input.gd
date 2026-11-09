extends "res://tests/support/input_scene_probe.gd"
## Live world, ordinary background AI; one stationary foe isolates input/feedback.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var starts: Array[Dictionary]=[]
var target: Enemy
func aim(point: Vector2) -> void:
	await aim_world(point)
	check(game.player.get_mouse_direction().dot((point-game.player.global_position).normalized())>.999,"Window/canvas scaling changed actual aim")
func press() -> void:
	await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false)
func idle() -> void:
	for i in range(160):
		if game.player.actor_context.actions.mode=="idle": return
		await frames(1)
	check(false,"Stroke did not finish")
func prime(weapon: String,id: String) -> void:
	var actor:=game.player; var actions:=actor.actor_context.actions; var store:=game.session.inventory
	actions.cancel(); store.equip("player",store.find_owned("player",weapon))
	for i in range(700):
		if actions.stamina.current>=95 and actor.actor_context.martial.reason(id,actor.actor_context).is_empty(): break
		await frames(1)
	check(actions.stamina.current>=95 and actor.actor_context.martial.reason(id,actor.actor_context).is_empty(),"Normal recovery/cooldown did not become ready")
	actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
	actor.skill_manager.shortcuts.bind_technique("quick_e",id)
	var data:=MartialArts.definition(id)
	for stage in range(data.followup_after[0]+1):
		# Prior strokes whiff; only the specified stage may confirm the branch.
		target.position=actor.position+Vector2(1000,0)
		if stage==data.followup_after[0]:
			target.health_component.hp=target.health_component.max_hp; target.health_component.invincible=false
			target.actor_context.actions.cancel(); target.actor_context.actions.stability.current=100
			target.position=actor.position+Vector2(45 if weapon!="river_bow" else 110,0)
		await frames(3); await aim(actor.position+Vector2(150,0)); await press()
		if stage<data.followup_after[0]: await idle()
	for i in range(150):
		if actions.technique_view(id).linked: break
		await frames(1)
	check(actions.technique_view(id).linked,"Real weapon contact did not offer a followup")
	if not actions.technique_view(id).linked: print("PRIME_DIAG ",JSON.stringify({"weapon":weapon,"facing":str(actions.facing),"player":str(actor.position),"target":str(target.position),"hp":target.health_component.hp,"dead":target.health_component.is_dead,"confirmed":actions.combo.hit_confirmed,"chain":actions.combo_snapshot()}))
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
	target=game.active_enemies[0]
	target.set_process(false); target.set_physics_process(false); target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED
	target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var actor:=game.player; var actions:=actor.actor_context.actions; var store:=game.session.inventory
	actor.health_component.regen_rate=.6; actor.mana_component.mp_regen_rate=3
	for id in ["river_sabre","river_spear","river_staff","river_bow"]: store.receive("player",id,1)
	store.receive_into("player.pocket","arrow",6)
	for id in MartialArts.IDS: actor.actor_context.martial.learn(id)
	game.session.facts.committed.connect(func(fact: Dictionary):
		if fact.kind=="physical_action_started" and fact.source=="player": starts.append(fact.data.duplicate(true)))
	for pair in [["river_sabre","blade_breaker"],["river_spear","spear_thrust"],["river_staff","staff_sweep"],["river_bow","bow_aim"]]:
		await prime(pair[0],pair[1])
		await capture("followup-ready-"+MartialArts.definition(pair[1]).weapon_type)
		# Wait for the final 200ms, not for a forced cancel of the current attack.
		for i in range(120):
			if actions.remaining<=.2: break
			await frames(1)
		var preview:=QuickslotView.technique_state(actor,actor.skill_manager.shortcuts.binding("quick_e"))
		check(preview.linked and preview.ready,"Quickslot preview failed to show the executable route")
		if pair[1]=="blade_breaker":
			await key(KEY_SHIFT,true)
			check(not QuickslotView.technique_state(actor,actor.skill_manager.shortcuts.binding("quick_e")).ready,"Shift preview promised a release without actual coating")
			await key(KEY_SHIFT,false)
		await key(KEY_E,true); await key(KEY_E,false)
		for i in range(100):
			if not starts.is_empty() and starts.back().technique==pair[1]: break
			await frames(1)
		check(starts.back().technique==pair[1] and starts.back().followup and actions.profile==MartialArts.definition(pair[1]).followup_profile,"Real E input did not commit its captured followup")
		await capture("followup-strike-"+MartialArts.definition(pair[1]).weapon_type)
		target.position=actor.position+Vector2(500,0)
		await idle()
		print("MARTIAL_INPUT ",JSON.stringify({"technique":pair[1],"action":starts.back(),"stamina":actions.stamina.current,"arrows":store.count("player","arrow"),"mp":actor.mana_component.mp}))
	# Ctrl selects base even with a live opportunity; no new quickslot is needed.
	await prime("river_sabre","blade_breaker")
	await key(KEY_CTRL,true)
	check(not QuickslotView.technique_state(actor,actor.skill_manager.shortcuts.binding("quick_e")).linked,"Ctrl preview retained the linked form")
	await idle(); await key(KEY_E,true); await key(KEY_E,false); await key(KEY_CTRL,false)
	check(starts.back().technique=="blade_breaker" and not starts.back().followup and actions.profile==MartialArts.definition("blade_breaker").profile,"Ctrl+E silently chose the linked form")
	await idle(); target.position=actor.position+Vector2(500,0)
	await key(KEY_F5,true); await key(KEY_F5,false); await key(KEY_F9,true); await key(KEY_F9,false)
	check(actions.combo_snapshot().is_empty() and not actions.technique_view("blade_breaker").linked and not paused and actor.mana_component.mp==60,"Restore retained an opportunity, paused the world or physical inputs spent MP")
	await fixture.close()
	if failures.is_empty(): print("PASS martial followup input: real hit-confirmed LMB/E routes for four weapons, shared live preview/HUD, natural stamina/cooldown, Ctrl+E base, actual arrows and F5/F9 transient cleanup; stationary target fixture")
	quit(0 if failures.is_empty() else 1)
