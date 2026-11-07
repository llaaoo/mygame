extends SceneTree
## Controlled geometry/resources, real executors: these are mechanism boundaries.
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=3) -> void:
	for i in range(n): await physics_frame
func isolate(actor: CharacterBody2D) -> void:
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	if actor is Enemy:
		actor.process_mode=Node.PROCESS_MODE_INHERIT
		actor.state_chart.process_mode=Node.PROCESS_MODE_DISABLED
		actor.set_process(false)
	var health:=actor.get_node("HealthComponent") as HealthComponent
	health.max_hp=500; health.hp=500; health.invincible=false
	actor.actor_context.actions.cancel()
	actor.actor_context.actions.stamina.current=100
func wall_at(game: GrayriverGame,point: Vector2) -> StaticBody2D:
	var wall:=StaticBody2D.new(); wall.collision_layer=1
	var collider:=CollisionShape2D.new(); var box:=RectangleShape2D.new(); box.size=Vector2(8,120)
	collider.shape=box; wall.add_child(collider); wall.position=point; game.region_root.add_child(wall)
	return wall
func run() -> void:
	var fixture:=Fixture.new(self)
	var game:=await fixture.boot()
	var player:=game.player
	var foe:=game.active_enemies[0]
	var ally:=game.active_enemies[1]
	for actor in [player,foe,ally]: isolate(actor)
	var base:=Vector2(-4000,800)
	player.position=base; foe.position=base+Vector2(300,0); ally.position=base+Vector2(600,200)
	var store:=game.session.inventory
	for id in ["river_spear","river_staff","river_sabre","fire_rag"]: store.receive("player",id,1)
	store.equip("player",store.find_owned("player","river_spear"))
	var actions:=player.actor_context.actions
	var swing:=Action.melee(player); swing.direction=Vector2.RIGHT
	check(actions.try_action(swing).accepted,"Spear input refused")
	actions.advance(.1)
	check(player.position.is_equal_approx(base),"Footwork occurred before active commitment")
	var stamina:=actions.stamina.current
	check(not actions.try_action(Action.dodge(Vector2.UP,player)).accepted and actions.stamina.current==stamina,"Committed windup allowed a free dodge cancel")
	var remaining:=actions.profile.windup+actions.profile.active-.1
	actions.advance(remaining)
	check(is_equal_approx(player.position.x,base.x+10) and actions.facing==Vector2.RIGHT,"Committed spear step lost distance or direction")
	actions.advance(.001)
	check(actions.try_action(Action.dodge(Vector2.UP,player)).accepted and actions.mode=="dodge","Recovery did not permit paid dodge cancel")
	actions.cancel(); actions.stamina.current=100; player.position=base
	var wall:=wall_at(game,base+Vector2(20,0)); await frames()
	check(actions.try_action(swing).accepted,"Wall sample attack refused")
	actions.advance(actions.profile.windup+actions.profile.active)
	check(player.position.x<base.x+10,"Committed step ignored body collision")
	wall.queue_free(); await frames()
	# A second hit cannot postpone an already running stagger indefinitely.
	var defense:=foe.actor_context.actions
	defense.stability.current=5; defense.stability.grace=0
	CombatExecutor.report_hit(player,foe,1,foe.position,null,["melee","physical"],"control.first",20)
	defense.advance(.4)
	var end_in:=defense.remaining
	foe.health_component.invincible=false
	CombatExecutor.report_hit(player,foe,1,foe.position,null,["melee","physical"],"control.second",20)
	check(defense.mode=="stagger" and is_equal_approx(defense.remaining,end_in),"Repeated damage renewed the stagger timer")
	defense.advance(end_in+.001)
	check(defense.mode=="idle" and defense.stability.grace>0,"Control lock had no recovery opening")
	# Qualifying push has a cooldown independent of ordinary action cancellation.
	var push:=load("res://content/martial/staff_sweep.tres").profile as AttackProfile
	foe.health_component.invincible=false
	var first:=CombatExecutor.report_hit(player,foe,1,foe.position,null,["melee","physical"],"push.first",0,push)
	defense.cancel("other_action"); foe.health_component.invincible=false
	var second:=CombatExecutor.report_hit(player,foe,1,foe.position,null,["melee","physical"],"push.second",0,push)
	check(first.pushed and not second.pushed and second.damage_dealt>0,"Repeated pushes bypassed recovery or removed ordinary damage")
	defense.advance(.91); foe.health_component.invincible=false
	check(CombatExecutor.report_hit(player,foe,1,foe.position,null,["melee","physical"],"push.third",0,push).pushed,"Push recovery never expired")
	defense.cancel("scope_left")
	check(defense.push_recovery==0,"Displacement transient survived scope cleanup")
	# A coated, rejected contact must not ignite oil before hit qualification.
	player.position=base; foe.position=base+Vector2(45,0)
	actions.cancel(); actions.stamina.current=100
	store.equip("player",store.find_owned("player","river_sabre"))
	check(player.actor_context.item_actions.begin("fire_rag"),"Real fire rag preparation refused")
	player.actor_context.item_actions.advance(1.3)
	check(store.count("player","fire_rag")==0,"Rag was not consumed at real commit")
	var surfaces:=SurfaceManager.instance
	var cell:=SurfaceManager.cell_at(foe.position)
	surfaces.force_set_surface(cell,"oiled",20)
	foe.health_component.invincible=true
	check(actions.try_action(swing).accepted,"Coated attack refused")
	actions.elapsed=actions.profile.windup+.001
	var rejected:=actions.contact(foe)
	check(not rejected.accepted and surfaces.get_surface(cell).state=="oiled","Rejected coated contact ignited ground before defense settled")
	actions.cancel(); actions.stamina.current=100; foe.health_component.invincible=false
	check(actions.try_action(swing).accepted,"Second coated attack refused")
	actions.elapsed=actions.profile.windup+.001
	var hit:=actions.contact(foe)
	check(hit.damage_dealt>0 and surfaces.get_surface(cell).state=="burning","Qualified coated hit failed to ignite actual oil")
	# Tactical MOVE must go through the existing hazard steering, not only its flag.
	GameRuntime.instance.get_simulation_runtime().clear_region()
	foe.position=base+Vector2(0,224); player.position=foe.position+Vector2(220,0)
	var next_cell:=SurfaceManager.cell_at(foe.position+Vector2(64,0))
	surfaces.force_set_surface(next_cell,"burning",20)
	foe.surface_awareness.steer(Vector2.RIGHT); foe.surface_awareness.tick(.3)
	foe.resolve_action(Action.move(Vector2.RIGHT,foe))
	check(defense.movement.dot(Vector2.RIGHT)<.99,"Tactical movement bypassed its evaluated hazard route")
	# Real body in a firing lane: reposition without spending arrow/stamina.
	GameRuntime.instance.get_simulation_runtime().clear_region()
	foe.position=base; player.position=base+Vector2(300,0); ally.position=base+Vector2(100,0)
	store.receive(foe.actor_context.id,"river_bow",1); store.receive_into(foe.actor_context.id+".pocket","arrow",2)
	store.equip(foe.actor_context.id,store.find_owned(foe.actor_context.id,"river_bow"))
	actions.cancel(); defense.cancel(); defense.stamina.current=100
	await frames()
	var brain:=EnemyCharacterBrain.new(foe)
	var arrows:=store.count(foe.actor_context.id,"arrow")
	check(not brain.shot_lane_clear(player),"Shooter saw through a real allied body")
	var choices:=brain.choose(player)
	check(choices.size()==1 and choices[0].action_type==Action.ActionType.MOVE and store.count(foe.actor_context.id,"arrow")==arrows and defense.stamina.current==100,"Blocked shooter committed or spent resources instead of moving")
	ally.position+=Vector2(0,150); await frames(); brain.tick(.3)
	check(brain.shot_lane_clear(player),"Clear firing lane was rejected")
	choices=brain.choose(player)
	check(choices.size()==1 and choices[0].action_type==Action.ActionType.MELEE,"Shooter did not resume once the firing lane cleared")
	# No false defense against a visible heavy strike facing away from the observer.
	if store.find_owned(foe.actor_context.id,"river_sabre").is_empty(): store.receive(foe.actor_context.id,"river_sabre",1)
	store.equip(foe.actor_context.id,store.find_owned(foe.actor_context.id,"river_sabre"))
	foe.position=player.position+Vector2(45,0)
	actions.cancel(); actions.stamina.current=100
	var away:=Action.melee(player); away.action_type=Action.ActionType.HEAVY_ATTACK; away.direction=Vector2.LEFT
	check(actions.try_action(away).accepted,"Away-facing heavy refused")
	brain=EnemyCharacterBrain.new(foe); brain.choose(player); brain.tick(.3); choices=brain.choose(player)
	check(not choices.any(func(action): return action.action_type in [Action.ActionType.DODGE,Action.ActionType.GUARD]),"AI defended against a windup pointed away from it")
	await fixture.close()
	if failures.is_empty(): print("PASS counterplay: collision footwork, bounded control, qualified coating, tactical hazard movement, real firing lanes and directional observation")
	quit(0 if failures.is_empty() else 1)
