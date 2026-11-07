extends "res://tests/support/input_scene_probe.gd"
## Real combat input against normal AI; gear and safe duel positions are fixtures.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var defenses: Array[Dictionary]=[]
func aim_at(point: Vector2) -> void:
	var screen:=root.get_canvas_transform()*point
	if DisplayServer.get_name()!="headless": Input.warp_mouse(screen)
	var motion:=InputEventMouseMotion.new(); motion.position=screen; motion.global_position=screen
	Input.parse_input_event(motion); Input.flush_buffered_events()
func mouse(button: MouseButton,held: bool) -> void:
	var event:=InputEventMouseButton.new(); event.position=root.get_mouse_position(); event.global_position=event.position; event.button_index=button; event.pressed=held
	Input.parse_input_event(event); Input.flush_buffered_events()
	await frames(1)
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	game=await fixture.boot()
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player
	var store:=game.session.inventory
	store.receive("player","river_sabre",1); store.receive("player","river_shield",1)
	store.equip("player",store.find_owned("player","river_sabre")); store.equip("player",store.find_owned("player","river_shield"))
	actor.position=Vector2(-4000,800); actor.get_node("Camera2D").reset_smoothing()
	var foe: Enemy
	for enemy in game.active_enemies:
		if str(enemy.get_meta("frontier_claim",""))=="river.enemy.camp.forest.3": foe=enemy; break
	check(foe!=null,"Normal forest guard fixture missing")
	if not foe: await fixture.close(); quit(1); return
	foe.position=actor.position+Vector2(160,0); foe._home_position=foe.position
	var old_serial:=actor.actor_context.actions._attack_sequence
	var observer:=func(target: Node2D,outcome: Dictionary):
		if target==actor: defenses.append(outcome.duplicate(true))
	CombatExecutor.instance.defense_resolved.connect(observer)
	var waiting:=0.0
	var guarded:=false
	while waiting<8 and not actor.health_component.is_dead:
		aim_at(foe.global_position)
		var action:=foe.actor_context.actions
		if action.mode=="attack" and action.elapsed<action.profile.windup and action.profile.guard_pressure==1:
			await mouse(MOUSE_BUTTON_RIGHT,true); guarded=true; break
		await frames(1); waiting+=1.0/Engine.physics_ticks_per_second
	check(guarded,"Normal AI did not create an observable ordinary attack")
	if guarded:
		waiting=0
		while waiting<1 and defenses.is_empty(): await frames(1); waiting+=1.0/Engine.physics_ticks_per_second
		check(defenses.any(func(outcome): return outcome.get("parried",false)),"Real timed RMB did not produce a precision block")
		check(actor.actor_context.actions._attack_sequence==old_serial,"Precision guard automatically attacked")
		await mouse(MOUSE_BUTTON_RIGHT,false)
		await capture("tactics-counter-window")
		aim_at(foe.global_position)
		var mp:=actor.mana_component.mp
		await mouse(MOUSE_BUTTON_LEFT,true); await mouse(MOUSE_BUTTON_LEFT,false)
		check(actor.actor_context.actions._attack_sequence==old_serial+1 and actor.actor_context.actions.counter_strike and actor.mana_component.mp==mp,"Actual LMB failed to spend the earned physical counter opportunity")
		await capture("tactics-counter-attack")
		await create_timer(.7).timeout
		check(actor.actor_context.actions.counter_remaining==0 and not paused,"Live combat preserved the temporary counter or paused the world")
	CombatExecutor.instance.defense_resolved.disconnect(observer)
	await fixture.close()
	if failures.is_empty(): print("PASS tactics input: normal AI readable windup, real RMB precision timing, manual LMB counter, live transient expiry; controlled equipment/duel positions")
	quit(0 if failures.is_empty() else 1)
