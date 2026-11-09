extends "res://tests/test_weapon_art_routes.gd"
## Controlled clocks and one stationary physical target. Real mouse coverage is separate.
func edge(phase: String,art := false,element := false) -> Action:
	var request:=Action.melee(actor); request.direction=Vector2.RIGHT
	request.params={"weapon_gesture":phase,"art":art,"release_enchantment":element}
	return request
func hold_prime(weapon: String,sequence: Array[String],flow := false) -> void:
	for node in game.region_root.get_children():
		if node is WeaponArrow: node.queue_free()
	await frames()
	if weapon!="river_bow" or not flow:
		await prime(weapon,sequence,flow)
		return
	await prime(weapon,sequence,false,false)
	var arrow: WeaponArrow
	for node in game.region_root.get_children():
		if node is WeaponArrow and not node.is_queued_for_deletion(): arrow=node; arrow.set_physics_process(false)
	check(arrow!=null,"Real charged-flow setup did not launch its arrow")
	if not arrow: return
	target.position=actor.position+Vector2(100,0); target.health_component.invincible=false
	await frames(); arrow._physics_process(.3)
	check(actions.weapon_art.confirmed(actions._family),"Actual arrow did not confirm bow's flow route")
	target.position=actor.position+Vector2(1000,0); actions.advance(actions.remaining)
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot()
	actor=game.player; actions=actor.actor_context.actions; target=game.active_enemies[0]
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	target.process_mode=Node.PROCESS_MODE_INHERIT; target.set_process(false); target.set_physics_process(false)
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var store:=game.session.inventory
	for id in ["river_sabre","river_spear","river_staff","river_bow"]:
		store.receive("player",id,1); weapons[id]=store.find_owned("player",id)
	store.receive_into("player.pocket","arrow",20)
	for id in MartialArts.IDS: actor.actor_context.martial.learn(id)
	for pair in [["river_sabre","blade_breaker"],["river_spear","spear_thrust"],["river_staff","staff_sweep"],["river_bow","bow_aim"]]:
		var data:=MartialArts.definition(pair[1])
		for flow in [false,true]:
			var sequence: Array[String]=[]
			sequence.assign(["light"] if pair[0]=="river_bow" and flow else ["light","light"] if flow else ["light","heavy"])
			await hold_prime(pair[0],sequence,flow)
			actions.stamina.current=100
			check(actions.try_action(edge("begin",true)).accepted,"No valid authored charge route")
			actions.advance(.32)
			var form:=data.charged_followup_profile if flow else data.charged_profile
			check(actions.weapon_hold_view().get("title","")==form.title,"HUD chose the wrong charged branch")
			var before:=actions.stamina.current; var arrows:=store.count("player","arrow")
			check(actions.try_action(edge("release")).accepted and actions.profile.title==form.title,"Held route failed to select authored heavy variant")
			check(is_equal_approx(before-actions.stamina.current,form.stamina_cost) and store.count("player","arrow")==arrows,"Heavy art cost was wrong or spent ammunition early")
			check(is_equal_approx(actions.profile.windup,maxf(.08,form.windup-.32)) and actions.profile!=form,"Charge credit failed or shared definition was modified")
			actions.advance(actions.remaining)
			check(store.count("player","arrow")==arrows-(1 if pair[0]=="river_bow" else 0),"Charged art did not commit exactly one actual arrow")
	# Actual charged breaker uses guard pressure through the same accepted hit.
	await hold_prime("river_sabre",["light","heavy"])
	actions.stamina.current=100; actions.try_action(edge("begin",true)); actions.advance(.32); actions.try_action(edge("release"))
	target.position=actor.position+Vector2(40,0); target.health_component.invincible=false
	target.actor_context.actions.guarding=true; target.actor_context.actions.facing=Vector2.LEFT; target.actor_context.actions.guard_age=1; target.actor_context.actions.stamina.current=100
	await frames(); actions.advance(actions.profile.windup+.01)
	print("HOLD_GUARD ",JSON.stringify({"stamina":target.actor_context.actions.stamina.current,"guarding":target.actor_context.actions.guarding,"hp":target.health_component.hp,"hits":actions._hit_targets.size(),"impact":actions.profile.impact,"pressure":actions.profile.guard_pressure}))
	check(target.actor_context.actions.stamina.current<40,"Charged breaker's authored pressure did not reach real guard cost")
	# The hold does not create a window after it has already expired.
	await hold_prime("river_sabre",["light","heavy"]); actions.advance(1.11)
	var before:=actions.stamina.current
	check(not actions.try_action(edge("begin",true)).accepted and actions.weapon_hold_view().is_empty() and actions.stamina.current==before,"Expired art was resurrected by holding")
	# Cost is revalidated against the heavy form, not the cheaper press preview.
	await hold_prime("river_sabre",["light","heavy"]); actions.stamina.current=100
	actions.try_action(edge("begin",true)); actions.advance(.32); actions.stamina.current=30
	check(actions.try_action(edge("release")).reason=="stamina" and actions.stamina.current==30 and actor.actor_context.martial.reason("blade_breaker",actor.actor_context).is_empty(),"Insufficient heavy stamina spent resources or started cooldown")
	# Exact threshold: one gesture gives one light below it, one heavy at it.
	for age in [.319,.32]:
		actions.cancel(); actions.stamina.current=100
		actions.try_action(edge("begin")); actions.advance(age); actions.try_action(edge("release"))
		check(actions.combo.active==(age<.32),"Tap/hold threshold emitted wrong stroke")
	# A timely press reserves the selected normal stage, even if released later.
	actions.cancel(); actions.stamina.current=100
	var hit:=Action.melee(actor); hit.direction=Vector2.RIGHT
	actions.try_action(hit); actions.advance(actions.remaining)
	actions.try_action(edge("begin")); actions.advance(.25); actions.try_action(edge("release"))
	check(actions.combo.current_index==1,"A short held continuation lost its selected normal stage")
	await fixture.close()
	if failures.is_empty(): print("PASS held weapon domain: all eight charged branches, authoritative threshold/charge credit, real costs/arrows/guard, expired/refused requests and normal stage reservation; controlled clock/target")
	quit(0 if failures.is_empty() else 1)
