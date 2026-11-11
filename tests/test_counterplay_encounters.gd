extends "res://tests/support/input_scene_probe.gd"
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
## Same game-generated save, controlled kit/arena, authored enemy caps and live AI.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var samples: Array[Dictionary]=[]
var total_harm := 0
var gross_stamina := 0.0
var gross_mp := 0
var total_stamina := 0.0
var previous_stamina := 100.0
func health_change(_source: Node2D,target: Node2D,damage: int) -> void:
	if target==game.player: total_harm+=damage
func fact_seen(fact: Dictionary) -> void:
	if fact.source=="player" and fact.kind=="physical_action_started": gross_stamina+=float(fact.data.stamina)
func cast_seen(plan: CastPlan) -> void: gross_mp+=plan.cost
func stamina_seen(current: float,_maximum: float) -> void:
	total_stamina+=maxf(0,previous_stamina-current)
	previous_stamina=current
func remaining_hp(enemy: Variant) -> int:
	return enemy.health_component.hp if is_instance_valid(enemy) and not enemy.health_component.is_dead else 0
func aim_at(point: Vector2) -> void:
	var screen:=root.get_canvas_transform()*point
	if DisplayServer.get_name()!="headless": Input.warp_mouse(screen)
	var event:=InputEventMouseMotion.new(); event.position=screen; event.global_position=screen
	Input.parse_input_event(event); Input.flush_buffered_events()
func movement(direction: Vector2) -> void:
	for pair in [[KEY_D,direction.x>.35],[KEY_A,direction.x<-.35],[KEY_S,direction.y>.35],[KEY_W,direction.y<-.35]]:
		var pressed:=Input.is_physical_key_pressed(pair[0])
		if pressed!=bool(pair[1]):
			var event:=InputEventKey.new(); event.keycode=pair[0]; event.physical_keycode=pair[0]; event.pressed=pair[1]
			Input.parse_input_event(event)
	Input.flush_buffered_events()
func swing() -> void:
	var event:=InputEventMouseButton.new(); event.position=root.get_mouse_position(); event.global_position=event.position; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames(1)
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	var stock:=game.session.inventory
	for id in ["river_sabre","oil_bottle","fire_rag"]: stock.receive("player",id,1)
	stock.equip("player",stock.find_owned("player","river_sabre"))
	game.player.skill_manager.shortcuts.bind_item("left","oil_bottle")
	game.player.skill_manager.shortcuts.bind_item("quick_e","fire_rag")
	game.player.skill_manager.equip_source("right",game.player.skill_manager.pool.get_skill("ignite"))
	game.player.position=Vector2(-4000,800)
	game._save_progress()
	var seed:=FileAccess.get_file_as_bytes("user://save_3.sav")
	await fixture.close()
	for style in ["basic","oil_fire","oil_fire_flank"]:
		var file:=FileAccess.open("user://save_3.sav",FileAccess.WRITE); file.store_buffer(seed); file.close()
		fixture=Fixture.new(self); game=await fixture.boot(true)
		var actor:=game.player
		actor.health_component.regen_rate=actor.character_definition.health_regen
		actor.mana_component.mp_regen_rate=actor.character_definition.mana_regen
		stock=game.session.inventory
		var guard: Enemy
		var caster: Enemy
		for enemy in game.active_enemies:
			if not guard and enemy.character_definition.id=="river_guard": guard=enemy
			if not caster and enemy.character_definition.id=="river_caster": caster=enemy
		check(guard!=null and caster!=null,"Existing mixed encounter actors missing")
		if not guard or not caster: await fixture.close(); quit(1); return
		var start:=Vector2(-4000,800)
		guard.position=start+Vector2(350,25); guard._home_position=guard.position
		caster.position=start+Vector2(450,-25); caster._home_position=caster.position
		actor.get_node("Camera2D").reset_smoothing()
		for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
		GameRuntime.instance.set_process(true)
		CombatExecutor.instance.damage_applied.connect(health_change)
		game.session.facts.committed.connect(fact_seen)
		actor.skill_manager.cast_committed.connect(cast_seen)
		actor.actor_context.actions.stamina.changed.connect(stamina_seen)
		total_harm=0; gross_stamina=0; gross_mp=0; total_stamina=0; previous_stamina=actor.actor_context.actions.stamina.current
		var initial: Dictionary={"hp":actor.health_component.hp,"mp":actor.mana_component.mp,"guard_hp":guard.health_component.hp,"caster_hp":caster.health_component.hp,"oil":stock.count("player","oil_bottle"),"rag":stock.count("player","fire_rag")}
		var began:=Time.get_ticks_msec()
		if style!="basic":
			aim_at(guard.position); await key(KEY_E,true); await key(KEY_E,false)
			await create_timer(1.3).timeout
			check(stock.count("player","fire_rag")==int(initial.rag)-1,"Safe preparation failed to consume the real coating")
		var threw:=false
		var ignited:=false
		var next_swing:=0
		var next_dodge:=0
		while not actor.health_component.is_dead and (remaining_hp(guard)>0 or remaining_hp(caster)>0) and Time.get_ticks_msec()-began<24000:
			var target:=guard if remaining_hp(guard)>0 else caster
			var offset:=target.global_position-actor.global_position
			aim_at(target.global_position)
			var threat:=target.actor_context.actions.attack_observation()
			var ranged_warning:=is_instance_valid(caster) and caster.can_see(actor) and caster.attack_preparation.is_preparing()
			if style=="oil_fire_flank" and Time.get_ticks_msec()>=next_dodge and not actor.actor_context.actions.busy() and (not threat.is_empty() and float(threat.windup)>0 or ranged_warning):
				movement(offset.normalized().orthogonal())
				await key(KEY_SPACE,true); await key(KEY_SPACE,false)
				await create_timer(.3).timeout; next_dodge=Time.get_ticks_msec()+850
			elif style!="basic" and not threw and offset.length()<280 and not actor.actor_context.actions.busy():
				movement(Vector2.ZERO)
				await key(KEY_Q,true); await create_timer(.6).timeout; await key(KEY_Q,false)
				await create_timer(1.0).timeout; threw=true
			elif style!="basic" and not ignited and offset.length()<65 and not actor.actor_context.actions.busy():
				movement(Vector2.ZERO); await key(KEY_R,true); await key(KEY_R,false)
				await create_timer(.35).timeout; ignited=true
			else:
				movement(offset.normalized() if offset.length()>40 else Vector2.ZERO)
				if offset.length()<60 and Time.get_ticks_msec()>=next_swing and not actor.actor_context.actions.busy():
					await swing(); next_swing=Time.get_ticks_msec()+620
			await frames(1)
		movement(Vector2.ZERO)
		await capture("counterplay-mixed-"+style)
		var result: Dictionary={"style":style,"seconds":(Time.get_ticks_msec()-began)/1000.0,"initial":initial,"damage_taken":total_harm,"hp":actor.health_component.hp,"mp":actor.mana_component.mp,"stamina":actor.actor_context.actions.stamina.current,"gross_attack_stamina":gross_stamina,"gross_mp":gross_mp,"oil_remaining":stock.count("player","oil_bottle"),"rag_remaining":stock.count("player","fire_rag"),"guard_hp":remaining_hp(guard),"caster_hp":remaining_hp(caster),"player_dead":actor.health_component.is_dead}
		result["total_stamina_spent"]=total_stamina
		samples.append(result); print("Live mixed encounter: "+JSON.stringify(result))
		check(gross_stamina>0 and not paused,"Encounter produced no real physical actions or paused its simulation")
		if style!="basic": check(threw and stock.count("player","oil_bottle")==int(initial.oil)-1,"Prepared encounter never paid for its physical throw")
		CombatExecutor.instance.damage_applied.disconnect(health_change)
		game.session.facts.committed.disconnect(fact_seen)
		actor.skill_manager.cast_committed.disconnect(cast_seen)
		actor.actor_context.actions.stamina.changed.disconnect(stamina_seen)
		await fixture.close()
	check(samples.size()==3 and samples[0].initial==samples[1].initial and samples[0].initial==samples[2].initial,"Encounter comparison did not start from the same saved resource/cap budget")
	var output:=FileAccess.open("user://counterplay_encounters.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"kind":"controlled same-save kit and geometry; live authored guard+caster, no AI freeze or cap increases","samples":samples},"  ")); output.close()
	if failures.is_empty(): print("PASS counterplay encounters: equal saved budget, real inputs, normal mixed AI and recorded resource/risk samples; no universal balance conclusion")
	quit(0 if failures.is_empty() else 1)
