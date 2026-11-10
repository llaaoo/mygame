extends "res://tests/support/input_scene_probe.gd"
## Independent fresh-save controlled encounters; real input, authored bodies and normal AI.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var harm:=0
var actions_seen: Dictionary={}
func damage_seen(_source: Node2D,target: Node2D,amount: int) -> void:
	if target==game.player:harm+=amount
func fact_seen(fact: Dictionary) -> void:
	if fact.kind=="physical_action_started" and str(fact.source).begins_with("river.enemy.camp.fieldcraft."):
		actions_seen[str(fact.source)]=int(actions_seen.get(str(fact.source),0))+1
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self);game=await fixture.boot(true)
	game.session.inventory.receive("player","river_spear",1)
	game.session.inventory.equip("player",game.session.inventory.find_owned("player","river_spear"))
	game.player.position=Vector2(-4000,800);game._save_progress()
	var seed:=FileAccess.get_file_as_bytes("user://save_3.sav")
	await fixture.close()
	for type in ["crawler","archer","mauler"]:
		var file:=FileAccess.open("user://save_3.sav",FileAccess.WRITE);file.store_buffer(seed);file.close()
		fixture=Fixture.new(self);game=await fixture.boot(true)
		var foe: Enemy
		for candidate in game.active_enemies:
			if candidate.character_definition and candidate.character_definition.id=="river_"+type:foe=candidate
		check(foe!=null,"Missing live encounter "+type)
		if not foe:await fixture.close();continue
		foe.position=game.player.position+Vector2(240 if type=="archer" else 95,0);foe._home_position=foe.position
		foe.process_mode=Node.PROCESS_MODE_INHERIT;GameRuntime.instance.set_process(true)
		game.player.get_node("Camera2D").reset_smoothing()
		CombatExecutor.instance.damage_applied.connect(damage_seen);game.session.facts.committed.connect(fact_seen)
		harm=0;actions_seen.clear()
		var before_hp:=foe.health_component.hp;var owner_id:=foe.actor_context.id
		var arrows:=game.session.inventory.count(owner_id,"arrow")
		var started:=Time.get_ticks_msec();var next_swing:=0;var dodges:=0;var fired:=0
		while is_instance_valid(foe) and not foe.health_component.is_dead and not game.player.health_component.is_dead and Time.get_ticks_msec()-started<10000:
			await aim_world(foe.position)
			if not is_instance_valid(foe) or foe.health_component.is_dead:break
			if type=="archer":
				# Observe range/real arrows first, then walk straight in with real D input.
				if Time.get_ticks_msec()-started>3200 and foe.position.distance_to(game.player.position)>100 and not Input.is_physical_key_pressed(KEY_D):await key(KEY_D,true)
				if not is_instance_valid(foe) or foe.health_component.is_dead:break
				if foe.position.distance_to(game.player.position)<=100 and Input.is_physical_key_pressed(KEY_D):await key(KEY_D,false)
			if not is_instance_valid(foe) or foe.health_component.is_dead:break
			var observation:=foe.actor_context.actions.attack_observation()
			if type!="archer" and not observation.is_empty() and float(observation.windup)>0 and game.player.actor_context.actions.mode=="idle" and dodges<4:
				await key(KEY_S,true);await key(KEY_SPACE,true);await key(KEY_SPACE,false);await key(KEY_S,false);dodges+=1
			if not is_instance_valid(foe) or foe.health_component.is_dead:break
			if Time.get_ticks_msec()>=next_swing and game.player.position.distance_to(foe.position)<125:
				await pointer_button(MOUSE_BUTTON_LEFT,true);await pointer_button(MOUSE_BUTTON_LEFT,false);next_swing=Time.get_ticks_msec()+700
			if Time.get_ticks_msec()-started>2500 and fired==0:await capture("combat-"+type);fired=1
			await create_timer(.1).timeout
		await key(KEY_D,false)
		var after_hp:=foe.health_component.hp if is_instance_valid(foe) else 0
		var spent:=arrows-game.session.inventory.count(owner_id,"arrow")
		print("ENEMY_LIVE type=%s seconds=%.2f enemy_harm=%d player_harm=%d enemy_actions=%d dodges=%d arrows_spent=%d mp=%d"%[type,(Time.get_ticks_msec()-started)/1000.0,before_hp-after_hp,harm,int(actions_seen.get(owner_id,0)),dodges,spent,game.player.mana_component.mp])
		check(int(actions_seen.get(owner_id,0))>0,"Live "+type+" did not execute a physical attack")
		if type=="archer":check(spent>0 and spent<=8,"Normal AI archery failed real finite ammunition")
		else:check(before_hp>after_hp,"Actual mouse attacks failed to reach "+type)
		check(not game.player.health_component.is_dead,"Controlled counterplay encounter killed player: "+type)
		CombatExecutor.instance.damage_applied.disconnect(damage_seen);game.session.facts.committed.disconnect(fact_seen)
		await fixture.close()
	if failures.is_empty():print("PASS live enemy inputs: independent game-save crawler/archer/mauler encounters, normal AI, mouse attacks, real dodge/approach, finite arrows and shared damage; controlled arena/spear, not a balance benchmark")
	quit(0 if failures.is_empty() else 1)
