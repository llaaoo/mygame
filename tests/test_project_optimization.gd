extends "res://tests/support/input_scene_probe.gd"
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var interactions := 0

func empty_fixture_position() -> Vector2:
	var navigation:=game.session.region.navigation
	var bounds:=navigation.bounds.grow(-160)
	for x in range(int(bounds.position.x),int(bounds.end.x),320):
		for y in range(int(bounds.position.y),int(bounds.end.y),320):
			var point:=Vector2(x,y);var cell:=navigation.cell(point)
			if not navigation.grid.is_in_boundsv(cell) or navigation.grid.is_point_solid(cell):continue
			if game.active_enemies.any(func(foe):return foe.position.distance_to(point)<800):continue
			var clear:=true
			for node in get_nodes_in_group("interactable"):
				if node is Node2D and node.global_position.distance_to(point)<160:clear=false;break
			if clear:return point
	return Vector2.INF

func run() -> void:
	var fixture:=Fixture.new(self);game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for foe in game.active_enemies:foe.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player;var controller:=actor.input_controller
	var placement:=empty_fixture_position()
	check(placement.is_finite(),"No safe, walkable empty fixture remains in this region")
	if not placement.is_finite():await fixture.close();quit(1);return
	actor.position=placement;await frames(2)
	var before:=controller.focus_query_count
	check(controller.interaction_target(true)==null,"Controlled empty space unexpectedly has an interaction")
	for i in range(200):check(controller.interaction_target()==null,"Negative focus cache invented a target")
	check(controller.focus_query_count==before+1,"Each empty-space label rescanned every world interactable")
	var point:=ExplorationInteractable.new();point.name="FocusProbe";point.position=actor.position+Vector2(40,0)
	point.callback=func():interactions+=1
	game.region_root.add_child(point)
	check(controller.interaction_target()==null,"Presentation cache unexpectedly changed within one physics sample")
	check(controller.interaction_target(true)==point,"Forced action validation reused a stale empty result")
	await key(KEY_F,true);await key(KEY_F,false)
	check(interactions==1,"Real F input did not execute the newly available interaction exactly once")
	point.queue_free()
	check(controller.interaction_target()!=point,"Queued-for-deletion focus survived presentation invalidation")
	var next:=ExplorationInteractable.new();next.position=actor.position+Vector2(40,0);game.region_root.add_child(next)
	check(controller.interaction_target(true)==next,"Could not prepare movement invalidation")
	actor.position+=Vector2(200,0)
	check(controller.interaction_target()==null,"Moving the player reused the old focused object")
	next.queue_free()
	var clock:=game.session.inventory.clock_seconds
	await key(KEY_I,true);await key(KEY_I,false)
	check(game.inventory_screen.visible and not paused,"Inventory input failed or paused normal simulation")
	await frames(4)
	check(game.session.inventory.clock_seconds>clock,"Live inventory stopped the world clock")
	await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
	check(game.active_enemies.all(func(foe):return foe.can_process()),"Optimization probe disabled normal AI")
	await fixture.close()
	if failures.is_empty():print("PASS project optimization: bounded empty focus sweeps, fresh forced F execution, deletion/movement invalidation and live inventory with normal AI")
	quit(0 if failures.is_empty() else 1)
