extends "res://tests/support/input_scene_probe.gd"
## Controlled inventory and starting positions, actual keys and live simulation.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var triggered: Array[String]=[]
func aim_at(point: Vector2) -> void:
	var screen:=root.get_canvas_transform()*point
	if DisplayServer.get_name()!="headless": Input.warp_mouse(screen)
	var event:=InputEventMouseMotion.new(); event.position=screen; event.global_position=screen
	Input.parse_input_event(event); Input.flush_buffered_events()
func swing() -> void:
	var event:=InputEventMouseButton.new(); event.position=root.get_mouse_position(); event.global_position=event.position; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	Input.parse_input_event(event); Input.flush_buffered_events(); await frames(1)
	event=event.duplicate(); event.pressed=false; Input.parse_input_event(event); Input.flush_buffered_events()
func on_trigger(_target: Node2D,title: String) -> void: triggered.append(title)
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	var actor:=game.player; var stock:=game.session.inventory
	stock.receive("player","river_staff",1); stock.receive_into("player.pocket","fire_rag",1)
	var uid:=stock.find_owned("player","river_staff"); stock.equip("player",uid)
	actor.actor_context.martial.learn("staff_sweep")
	actor.skill_manager.shortcuts.bind_item("left","fire_rag")
	var base:=Vector2(-4000,800); actor.position=base; actor.get_node("Camera2D").reset_smoothing()
	var target:=game.active_enemies[0]
	target.position=base+Vector2(45,0); target.process_mode=Node.PROCESS_MODE_INHERIT
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.set_process(false)
	GameRuntime.instance.set_process(true)
	CombatExecutor.instance.enchantment_triggered.connect(on_trigger)
	await frames(5); aim_at(target.position)
	var mp:=actor.mana_component.mp
	await key(KEY_Q,true); await key(KEY_Q,false); await create_timer(1.3).timeout
	check(stock.coating(uid)!=null and stock.count("player","fire_rag")==0,"Real Q did not coat the actual weapon")
	await swing(); await create_timer(.9).timeout
	var buffs:=target.get_node("BuffManager") as BuffManager
	check(not buffs.has_buff("burning") and buffs.buildup.snapshot().has("flame"),"First actual LMB did not leave partial fire buildup")
	await capture("enchantment-partial-buildup")
	aim_at(target.position); await swing(); await create_timer(.5).timeout
	check(triggered.size()==1 and buffs.has_buff("burning") and stock.coating(uid)!=null,"Second LMB failed to trigger burning while preserving the coating")
	await capture("enchantment-threshold-trigger")
	await create_timer(.7).timeout
	# Earn a light-heavy route away from the foes, preserving the real coating.
	await aim_world(actor.position+Vector2(0,-150))
	await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false)
	await create_timer(1.0).timeout
	await pointer_button(MOUSE_BUTTON_LEFT,true); await create_timer(.37).timeout; await pointer_button(MOUSE_BUTTON_LEFT,false)
	for i in range(130):
		if actor.actor_context.actions.mode=="idle": break
		await frames(1)
	# Second target keeps authored AI, resources and caps; its response may evade.
	var foe: Enemy
	for enemy in game.active_enemies:
		if is_instance_valid(enemy) and str(enemy.get_meta("frontier_claim",""))=="river.enemy.camp.forest.3": foe=enemy; break
	check(foe!=null,"Existing normal-AI guard missing")
	if not foe: await fixture.close(); quit(1); return
	foe.position=base+Vector2(210,0); foe._home_position=foe.position; foe.process_mode=Node.PROCESS_MODE_INHERIT
	var hp:=foe.health_component.hp
	await frames(4); aim_at(foe.position)
	await key(KEY_CTRL,true); await key(KEY_SHIFT,true); await pointer_button(MOUSE_BUTTON_LEFT,true); await pointer_button(MOUSE_BUTTON_LEFT,false)
	check(actor.actor_context.actions.mode=="attack" and stock.coating(uid)!=null,"Ctrl+Shift+LMB did not preserve coating during its windup")
	await capture("enchantment-wave-warning")
	await key(KEY_SHIFT,false); await key(KEY_CTRL,false)
	var found:=false
	for i in range(80):
		for node in game.region_root.get_children():
			if node is EnchantmentWave and node.radius>=60 and not node.is_queued_for_deletion(): found=true
		if found: break
		await frames(1)
	check(found and stock.coating(uid)==null and actor.mana_component.mp==mp,"Latched Shift intent failed to release/consume the real enchantment without MP")
	await capture("enchantment-travelling-wave")
	await create_timer(.6).timeout
	print("Enchantment input sample: "+JSON.stringify({"kind":"controlled kit/positions; LMB target decisions disabled, wave target normal AI","mp":actor.mana_component.mp,"coating_remaining":stock.coating(uid)!=null,"triggered":triggered,"guard_hp_before":hp,"guard_hp_after":foe.health_component.hp if is_instance_valid(foe) else 0,"guard_stamina":foe.actor_context.actions.stamina.current if is_instance_valid(foe) else 0,"wave_captured":found}))
	CombatExecutor.instance.enchantment_triggered.disconnect(on_trigger)
	game._save_progress(); await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	check(game.session.inventory.item(uid)!=null and game.session.inventory.coating(uid)==null,"Actual reentry restored a consumed enchantment or replaced weapon UID")
	await fixture.close()
	if failures.is_empty(): print("PASS enchantment input: real rag/LMB buildup and proc, latched Ctrl+Shift+LMB, normal-AI wave sample, actual MP/coating and consumed-UID save/reentry")
	quit(0 if failures.is_empty() else 1)
