extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
class RejectingExecutor extends SkillExecutor:
	func execute(_skill: SkillData,_context: CastContext) -> bool: return false
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=3) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var fixture:=Fixture.new(self)
	var game:=await fixture.boot()
	var actor:=game.player
	var context:=actor.actor_context
	var actions:=context.actions
	var store:=context.items
	actor.position=Vector2(-3059,-1210)
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var target:=game.active_enemies[0]
	target.position=actor.position+Vector2(80,0)
	var request:=Action.melee(actor); request.direction=Vector2.RIGHT
	for id in ["river_sabre","river_spear","river_staff","river_bow"]: store.receive("player",id,1)
	store.equip("player",store.find_owned("player","river_sabre"))
	check(actions.try_action(request).accepted and actions.profile==load("res://content/weapons/blade.tres").attacks[0],"Blade did not use its own first stroke")
	var first_damage:=actions.profile.damage_multiplier
	actions.advance(.61)
	check(actions.mode=="idle" and actions.combo_index==1,"A single press automatically chained another attack")
	check(actions.try_action(request).accepted and actions.profile.damage_multiplier>first_damage,"New attack press did not progress the chain")
	actions.advance(2)
	check(actions.try_action(request).accepted and actions.profile.damage_multiplier==first_damage,"Expired chain window did not reset stroke")
	actions.cancel(); actions.stamina.current=100
	store.equip("player",store.find_owned("player","river_spear"))
	check(actions.try_action(request).accepted and actions.profile.reach>=100 and actions.profile.angle_degrees<45,"Spear is just a reskinned short blade")
	actions.elapsed=actions.profile.windup+.01
	await frames()
	target.health_component.invincible=false
	check(actions.contact(target).accepted,"Spear long reach did not produce real contact")
	actions.interrupt(.5)
	check(actions.combo_index==0 and actions.combo_remaining==0,"Stagger preserved a prepared chain finisher")
	actions.cancel(); actions.stamina.current=100
	context.martial.learn("spear_thrust")
	var skill:=Action.new(); skill.action_type=Action.ActionType.TECHNIQUE; skill.skill_id="spear_thrust"; skill.direction=Vector2.RIGHT
	var mp:=actor.mana_component.mp
	check(actions.try_action(skill).accepted and actions.profile.reach==145 and actor.mana_component.mp==mp and actions.stamina.current==75,"Martial technique used magic costs or ignored physical reach")
	actions.cancel()
	var stamina:=actions.stamina.current
	check(not actions.try_action(skill).accepted and actions.stamina.current==stamina,"Martial cooldown failed or spent stamina on rejection")
	context.martial.ready_at.clear()
	store.equip("player",store.find_owned("player","river_sabre"))
	check(not actions.try_action(skill).accepted and actions.stamina.current==stamina,"Spear technique ignored actual weapon requirement")
	store.equip("player",store.find_owned("player","river_bow"))
	actions.stamina.current=100
	check(not actions.try_action(request).accepted and actions.stamina.current==100,"Empty bow fired or charged stamina without ammunition")
	store.receive_into("player.pocket","arrow",3)
	check(actions.try_action(request).accepted,"Nocking a real arrow refused")
	actions.interrupt(.5)
	check(store.count("player","arrow")==3,"Interrupted bow windup consumed ammunition before release")
	actions.cancel(); actions.stamina.current=100
	target.process_mode=Node.PROCESS_MODE_INHERIT
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED
	target.set_process(false)
	target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	target.position=actor.position+Vector2(200,0)
	await frames()
	var wall:=StaticBody2D.new(); wall.collision_layer=1
	var collider:=CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=Vector2(20,100); collider.shape=shape; wall.add_child(collider)
	wall.position=actor.position+Vector2(100,0); game.region_root.add_child(wall)
	await frames()
	check(not target.can_see(actor),"Normal enemy vision saw through a solid wall")
	var hp:=target.health_component.hp
	check(actions.try_action(request).accepted and store.count("player","arrow")==3,"Bow consumed its arrow before release")
	actions.advance(.6)
	check(store.count("player","arrow")==2,"Bow release did not commit one actual pocket arrow")
	var arrows:=game.region_root.get_children().filter(func(node): return node is WeaponArrow)
	check(arrows.size()==1,"Bow launched no physical projectile")
	if not arrows.is_empty():
		var arrow:=arrows[0] as WeaponArrow; arrow.set_physics_process(false); arrow._physics_process(.5)
	await frames()
	check(target.health_component.hp==hp,"Arrow passed through a wall")
	wall.queue_free(); await frames()
	check(target.can_see(actor),"Enemy lost line of sight in open ground")
	actions.cancel(); actions.stamina.current=100; target.health_component.invincible=false
	check(actions.try_action(request).accepted,"Second bow shot failed")
	actions.advance(.6)
	arrows=game.region_root.get_children().filter(func(node): return node is WeaponArrow and not node.is_queued_for_deletion())
	if not arrows.is_empty():
		var arrow:=arrows[0] as WeaponArrow; arrow.set_physics_process(false); arrow._physics_process(.5)
	await frames()
	check(target.health_component.hp<hp and actor.mana_component.mp==mp and store.count("player","arrow")==1,"Arrow has no real physical damage or used mana")
	# Normal brain reacts to visible physical telegraphs, routes dodge through executor.
	actions.cancel(); actions.stamina.current=100
	store.equip("player",store.find_owned("player","river_sabre"))
	store.receive(target.actor_context.id,"river_sabre",1)
	store.equip(target.actor_context.id,store.find_owned(target.actor_context.id,"river_sabre"))
	target.actor_context.actions.cancel(); target.actor_context.actions.stamina.current=100
	target.position=actor.position+Vector2(40,0); await frames()
	check(actions.try_action(request).accepted,"Could not start visible light telegraph")
	target.character_brain._clock=0; target.character_brain._defense_cooldown=0
	var chosen:=target.character_brain.choose(actor)
	check(chosen.size()==1 and chosen[0].action_type==Action.ActionType.GUARD,"Enemy did not respond to a visible light windup")
	if chosen.size()==1: target.resolve_action(chosen[0])
	check(target.actor_context.actions.guarding,"Enemy guard intent never reached shared physical executor")
	actions.cancel(); actions.stamina.current=100
	var heavy:=Action.melee(actor); heavy.action_type=Action.ActionType.HEAVY_ATTACK; heavy.direction=Vector2.RIGHT
	check(actions.try_action(heavy).accepted,"Could not start heavy telegraph")
	target.actor_context.actions.cancel(); target.actor_context.actions.stamina.current=100
	target.character_brain._clock=0; target.character_brain._defense_cooldown=0
	chosen=target.character_brain.choose(actor)
	check(chosen.size()==1 and chosen[0].action_type==Action.ActionType.DODGE,"Enemy did not distinguish heavy and light windups")
	if chosen.size()==1: target.resolve_action(chosen[0])
	check(target.actor_context.actions.mode=="dodge" and target.actor_context.actions.stamina.current<100,"Enemy dodge bypassed physical execution or cost")
	target.actor_context.actions.cancel(); target.position+=Vector2(1000,0)
	# Timed sigils: natural decay plus uses, exact rollback, no implicit replacement.
	actions.cancel()
	actor.position=Vector2(-3500,2000)
	var manager:=actor.skill_manager
	var controller:=manager.combinations
	manager.known_actions["inscribe"]=true; manager.known_actions["pulse"]=true
	manager.equip_slot(0,manager.pool.get_skill("inscribe")); manager.equip_slot(1,manager.pool.get_skill("pulse"))
	actor.mana_component.mp=actor.mana_component.max_mp
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Timed rune placement refused")
	controller.tick(1)
	var field:=controller.field
	field.tick(12)
	var budget:=field.remaining
	var original_executor:=manager.executor
	manager.executor=RejectingExecutor.new(); manager.add_child(manager.executor)
	check(manager.use_slot(1,actor,Vector2.RIGHT),"Rune combo could not enter preparation")
	controller.tick(1)
	check(is_equal_approx(field.remaining,budget),"Rejected executor spent or refilled sigil time")
	manager.executor.queue_free(); manager.executor=original_executor
	controller.cooldowns.clear()
	check(manager.use_slot(1,actor,Vector2.RIGHT),"Actual rune trigger failed after rollback")
	controller.tick(1)
	check(is_equal_approx(field.remaining,budget-40),"Rune trigger did not spend only its time budget")
	field.tick(field.remaining-.1)
	controller.cooldowns.clear()
	check(manager.use_slot(1,actor,Vector2.RIGHT),"Final partial sigil budget could not be used")
	controller.tick(1)
	check(field.remaining==0,"Final sigil use extended lifetime below zero")
	await fixture.close()
	if failures.is_empty(): print("PASS weapon actions: manual chains, distinct reach, martial stamina/cooldown, real arrows/walls, timed sigil rollback")
	quit(0 if failures.is_empty() else 1)
