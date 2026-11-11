extends "res://tests/support/input_scene_probe.gd"
## Controlled position/stock and stationary collision fixtures; real Q/RMB/LMB.
## The world and authored enemies keep normal simulation, far from this test lane.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")

func obstacle(layer: int, point: Vector2, area:=false) -> CollisionObject2D:
	var body: CollisionObject2D=Area2D.new() if area else StaticBody2D.new()
	body.collision_layer=layer;body.collision_mask=0;body.position=point
	var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new()
	shape.size=Vector2(16,160);collision.shape=shape;body.add_child(collision)
	game.region_root.add_child(body)
	return body

func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self);game=await fixture.boot()
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies:enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player
	var store:=game.session.inventory
	var use:=actor.actor_context.item_actions as ItemActionController
	store.receive("player","oil_bottle",5)
	check(actor.skill_manager.shortcuts.bind_item("left","oil_bottle"),"Could not bind real oil bottles to Q")
	var cases: Array[Dictionary]=[
		{"name":"wall","layer":1,"area":false,"distance":166.0},
		{"name":"actor_layer","layer":2,"area":false,"distance":166.0},
		{"name":"hit_area","layer":8,"area":true,"distance":166.0},
		{"name":"unobstructed","layer":0,"area":false,"distance":360.0},
	]
	for index in cases.size():
		var entry:=cases[index]
		actor.position=Vector2(-4000,800+index*256)
		actor.get_node("Camera2D").reset_smoothing()
		var start:=actor.global_position
		# Layer 4 is not a throw obstruction. The actor's own body is excluded.
		var ignored:=obstacle(4,start+Vector2(64,0))
		var blocker: CollisionObject2D
		if int(entry.layer)>0:blocker=obstacle(int(entry.layer),start+Vector2(176,0),bool(entry.area))
		await frames(6);await aim_world(start+Vector2(450,0))
		var stock:=store.count("player","oil_bottle")
		var mana:=actor.mana_component.mp
		await key(KEY_Q,true)
		check(use.aiming and store.count("player","oil_bottle")==stock,"Q spent a bottle before committing: "+str(entry.name))
		if index==0:
			await pointer_button(MOUSE_BUTTON_RIGHT,true);await pointer_button(MOUSE_BUTTON_RIGHT,false)
			await key(KEY_Q,false);await frames(10)
			check(not use.busy() and store.count("player","oil_bottle")==stock,"RMB cancellation or old Q release consumed a bottle")
			await key(KEY_Q,true)
		var predicted:=use.aim_endpoint()
		var expected:=start+Vector2(float(entry.distance),0)
		check(predicted.distance_to(expected)<.2,"Preview disagrees with independently placed first obstruction: "+str(entry.name))
		await capture("throw-preview-"+str(entry.name))
		if index==0:
			await pointer_button(MOUSE_BUTTON_LEFT,true);await pointer_button(MOUSE_BUTTON_LEFT,false)
		await key(KEY_Q,false)
		var dose: ThrownDose
		var deadline:=Time.get_ticks_msec()+4000
		while Time.get_ticks_msec()<deadline:
			if not is_instance_valid(dose):
				for child in game.region_root.get_children():
					if child is ThrownDose and child.global_position.y>start.y-1 and child.global_position.y<start.y+1:dose=child;break
			if is_instance_valid(dose) and dose.spent:break
			await frames(1)
		check(is_instance_valid(dose) and dose.spent,"No actual projectile impact: "+str(entry.name))
		if is_instance_valid(dose):
			check(dose.global_position.distance_to(predicted)<.2,"Live carrier and displayed endpoint disagree: "+str(entry.name))
			var sample:=start+Vector2(128 if blocker else 320,0)
			check(SurfaceManager.instance.surface_at(sample).get("state","")=="oiled","Impact did not apply real oil to the reachable ground: "+str(entry.name))
			print("THROW_CASE "+JSON.stringify({"case":entry.name,"preview_distance":predicted.distance_to(start),"impact_distance":dose.global_position.distance_to(start),"bottles_spent":stock-store.count("player","oil_bottle")}))
		check(store.count("player","oil_bottle")==stock-1 and actor.mana_component.mp==mana,"Throw spent/refunded the wrong resources: "+str(entry.name))
		check(not paused,"Throw input paused the world")
		if blocker:blocker.queue_free()
		ignored.queue_free();await frames(30)
	await fixture.close()
	if failures.is_empty():print("PASS throw trajectory input: Q aim/release, RMB cancel, LMB confirmation, own-body/layer-4 exclusion, wall/body/area first impact and empty reach, one actual bottle and oil surface per commit; controlled static fixtures")
	quit(0 if failures.is_empty() else 1)
