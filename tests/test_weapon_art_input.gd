extends "res://tests/support/input_scene_probe.gd"
## Live world/AI; real physical inputs in a controlled safe location.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var starts: Array[Dictionary]=[]
func click_attack(heavy := false) -> void:

	await pointer_button(MOUSE_BUTTON_LEFT,true)
	if heavy:
		var until:=game.player.actor_context.actions.weapon_art.clock+.36
		while game.player.actor_context.actions.weapon_art.clock<until: await frames(1)
	await pointer_button(MOUSE_BUTTON_LEFT,false)

func idle() -> void:
	for i in range(180):
		if game.player.actor_context.actions.mode=="idle": return
		await frames(1)
	check(false,"Physical action did not finish")
func ready(id: String) -> void:
	for i in range(700):
		if game.player.actor_context.actions.stamina.current>=95 and game.player.actor_context.martial.reason(id,game.player.actor_context).is_empty(): return
		await frames(1)
	check(false,"Natural stamina/cooldown recovery did not become ready")
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player; var actions:=actor.actor_context.actions; var store:=game.session.inventory
	actor.health_component.regen_rate=.6; actor.mana_component.mp_regen_rate=3
	actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
	for id in ["river_sabre","river_spear","river_staff","river_bow"]: store.receive("player",id,1)
	store.receive_into("player.pocket","arrow",8)
	for id in MartialArts.IDS: actor.actor_context.martial.learn(id)
	for source in QuickslotLoadout.SOURCES:
		if actor.skill_manager.shortcuts.binding(source).get("kind","")=="technique": actor.skill_manager.shortcuts.clear(source)
	game.session.facts.committed.connect(func(fact: Dictionary):
		if fact.kind=="physical_action_started" and fact.source=="player": starts.append(fact.data.duplicate(true)))
	await frames(12); await aim_world(actor.position+Vector2(150,0))
	var stamina:=actions.stamina.current
	await key(KEY_V,true); await key(KEY_V,false)
	check(starts.is_empty() and actions.stamina.current==stamina,"Shared key cast a free skill without a sequence")
	# Let the previous refusal finish displaying before recording a new window.
	await frames(220)
	for pair in [["river_sabre","blade_breaker"],["river_spear","spear_thrust"],["river_staff","staff_sweep"],["river_bow","bow_aim"]]:
		store.equip("player",store.find_owned("player",pair[0])); await ready(pair[1])
		await aim_world(actor.position+Vector2(150,0))
		var before:=starts.size(); var arrows:=store.count("player","arrow")
		await click_attack(); await idle()
		await aim_world(actor.position+Vector2(150,0)); await click_attack(true); await idle()
		var art:=actions.weapon_art_view()
		check(not art.is_empty() and art.route=="power" and art.technique==pair[1] and art.remaining>.8,"Actual light/hold-heavy did not open the shared-key window")
		await capture("shared-art-"+MartialArts.definition(pair[1]).weapon_type)
		await key(KEY_V,true)
		check(starts.size()==before+3 and starts.back().weapon_art and starts.back().art_route=="power" and starts.back().technique==pair[1],"Real V did not select the current weapon's authored art")
		check(actions.technique_status().contains(MartialArts.definition(pair[1]).title),"Shared art gave no executing-name feedback")
		await idle(); await frames(8); await key(KEY_V,false)
		check(starts.size()==before+3,"Held shared key repeated or triggered a combo macro")
		check(actions.technique_status().contains("冷却"),"Slot-free art had no cooldown feedback")
		check(store.count("player","arrow")==arrows-(3 if pair[0]=="river_bow" else 0),"Bow pattern/art did not spend exactly three actual arrows")
		print("SHARED_ART_INPUT ",JSON.stringify({"technique":pair[1],"strokes":starts.slice(before),"stamina":actions.stamina.current,"arrows":store.count("player","arrow"),"mp":actor.mana_component.mp}))
	# The same key selects the flow branch from a real hit, with no skill binding.
	store.equip("player",store.find_owned("player","river_sabre")); await ready("blade_breaker")
	var target:=game.active_enemies[0]
	target.set_process(false); target.set_physics_process(false); target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	target.position=actor.position+Vector2(1000,0)
	await aim_world(actor.position+Vector2(150,0)); await click_attack(); await idle()
	target.position=actor.position+Vector2(45,0); await frames(3)
	await aim_world(actor.position+Vector2(150,0)); await click_attack(); await idle()
	check(not actions.weapon_art_view().is_empty() and actions.weapon_art_view().route=="flow","Actual terminal hit did not select the flow branch")
	await capture("shared-art-flow")
	# Remap through the same binding owner; actual H input executes the window.
	var event:=InputEventKey.new(); event.keycode=KEY_H; event.physical_keycode=KEY_H
	check(InputBindings.assign("weapon_art",event,false).accepted,"Shared art could not be rebound")
	await key(KEY_H,true); await key(KEY_H,false)
	check(starts.back().weapon_art and starts.back().art_route=="flow" and actions.profile.title=="截势斩","Remapped shared key lost the exact flow route")
	target.position=actor.position+Vector2(1000,0); await idle()
	check(QuickslotLoadout.SOURCES.all(func(source): return actor.skill_manager.shortcuts.binding(source).get("kind","")!="technique"),"Universal arts silently occupied shortcut slots")
	await ready("blade_breaker")
	await aim_world(actor.position+Vector2(150,0)); await click_attack(); await idle(); await click_attack(true); await idle()
	check(not actions.weapon_art_view().is_empty(),"No window for interface cancellation test")
	await key(KEY_I,true); await key(KEY_I,false); await key(KEY_H,true)
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	var count:=starts.size(); await frames(10); await key(KEY_H,false)
	check(actions.weapon_art_view().is_empty() and starts.size()==count and not paused,"Held art input escaped the live interface")
	await key(KEY_F5,true); await key(KEY_F5,false); await key(KEY_F9,true); await key(KEY_F9,false)
	check(actions.weapon_art_view().is_empty() and actor.mana_component.mp==60,"Restore retained a window or physical arts spent MP")
	await fixture.close()
	if failures.is_empty(): print("PASS shared weapon art input: real light/hold-heavy/V on four weapons, slot-free flow/H remap, natural budgets, exact arrows, no repeats/UI ghost and F5/F9 cleanup; one stationary hit target")
	quit(0 if failures.is_empty() else 1)
