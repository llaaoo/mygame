extends SceneTree
## Controlled geometry and health resets isolate contact/defense, not balance.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
var game: GrayriverGame
var actor: Player
var target: Enemy
var actions: ActorActionController
var weapons: Dictionary={}
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames() -> void:
	for i in range(3): await physics_frame
func prime(id: String,index: int) -> void:
	actions.cancel(); actor.position=Vector2(-4000,800)
	game.session.inventory.equip("player",weapons[id])
	target.position=actor.position+Vector2(800,0)
	target.actor_context.actions.cancel("scope_left"); target.actor_context.actions.stability.current=100
	target.actor_context.actions.stability.grace=0
	target.health_component.hp=target.health_component.max_hp; target.health_component.invincible=false
	var request:=Action.melee(actor); request.direction=Vector2.RIGHT
	for stage in range(index+1):
		actions.stamina.current=100
		check(actions.try_action(request).accepted,"Contact fixture could not accept real stroke")
		if stage<index: actions.advance(actions.remaining)
	actions.advance(actions.profile.windup+.01)
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot()
	actor=game.player; actions=actor.actor_context.actions; target=game.active_enemies[0]
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	target.process_mode=Node.PROCESS_MODE_INHERIT; target.set_process(false); target.set_physics_process(false)
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED
	target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	for id in ["river_sabre","river_spear","river_staff"]:
		game.session.inventory.receive("player",id,1); weapons[id]=game.session.inventory.find_owned("player",id)
	await prime("river_sabre",0)
	target.position=actor.position+Vector2.from_angle(deg_to_rad(40))*50; await frames()
	check(actions.contact(target).damage_dealt>0,"Blade opening sweep lost its lateral contact")
	target.health_component.invincible=false
	check(not actions.contact(target).accepted,"One combo stroke hit the same target twice")
	await prime("river_sabre",2)
	target.position=actor.position+Vector2.from_angle(deg_to_rad(40))*50; await frames()
	check(not actions.contact(target).accepted,"Blade straight finisher retained the old wide slash")
	target.position=actor.position+Vector2(50,0); await frames()
	check(actions.contact(target).damage_dealt>0,"Blade finisher had no real forward hit")
	await prime("river_spear",2)
	target.position=actor.position+Vector2(122,0); await frames()
	check(actions.contact(target).damage_dealt>0,"Spear final thrust did not extend actual reach")
	await prime("river_spear",2)
	target.position=actor.position+Vector2.from_angle(deg_to_rad(20))*100; await frames()
	check(not actions.contact(target).accepted,"Spear finisher could not be avoided by leaving the narrow line")
	await prime("river_staff",1)
	target.position=actor.position+Vector2(70,0); await frames()
	check(not actions.contact(target).accepted,"Staff butt strike inherited the wide sweep's reach")
	target.position=actor.position+Vector2(45,0); await frames()
	check(actions.contact(target).damage_dealt>0,"Staff short middle strike had no real contact")
	await prime("river_staff",2)
	target.position=actor.position+Vector2.from_angle(deg_to_rad(60))*65; await frames()
	var hit:=actions.contact(target); var before:=target.position
	target.actor_context.actions.advance(.18)
	check(hit.pushed and target.position.distance_to(before)>10 and target.position.distance_to(before)<=18.01,"Staff finisher did not use the real shared collision push")
	await prime("river_staff",2)
	target.position=actor.position+Vector2(55,0); await frames()
	var defense:=target.actor_context.actions; defense.guarding=true; defense.facing=Vector2.LEFT; defense.stamina.current=100
	check(actions.contact(target).blocked and defense._push_remaining==0,"Blocked finisher still applied its push")
	# Brain uses the next authored reach, preserving normal observation/cost rules.
	actions.cancel(); actor.position=Vector2(-4000,800); target.position=actor.position+Vector2(70,0)
	var store:=game.session.inventory; var owner:=target.actor_context.id
	store.receive(owner,"river_staff",1); store.equip(owner,store.find_owned(owner,"river_staff"))
	defense.cancel(); defense.stamina.current=100
	var request:=Action.melee(target); request.direction=Vector2.RIGHT
	defense.try_action(request); defense.advance(defense.remaining)
	defense.stamina.current=100
	await frames()
	var chosen:=EnemyCharacterBrain.new(target).choose(actor)
	check(not chosen.any(func(action): return action.action_type in [Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK]),"AI swung a 58-range second strike from 70 away")
	actions.guarding=true
	chosen=EnemyCharacterBrain.new(target).choose(actor)
	check(chosen.size()==1 and chosen[0].action_type==Action.ActionType.HEAVY_ATTACK,"AI used the short normal-stage reach for its standalone guard-breaking attack")
	if chosen.size()==1 and chosen[0].action_type==Action.ActionType.HEAVY_ATTACK:
		check(defense.try_action(chosen[0]).accepted and defense.profile.reach==76 and defense.profile.title=="开门扫" and defense.combo_snapshot().is_empty(),"AI heavy preview and actual standalone execution disagree")
	await fixture.close()
	if failures.is_empty(): print("PASS combo contacts: blade lateral/straight distinction, one hit per family, spear long narrow line, staff short middle/push finisher, actual collision displacement, blocked push rejection and next-stage AI reach")
	quit(0 if failures.is_empty() else 1)
