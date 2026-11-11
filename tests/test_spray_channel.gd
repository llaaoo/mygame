extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
class RejectingExecutor extends SkillExecutor:
	func can_execute(_skill: SkillData,_actor: Node2D) -> bool: return false
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=4) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot()
	var actor:=game.player
	actor.position=Vector2(-3500,2000)
	actor.mana_component.mp=0
	var ctx:=actor.actor_context
	var channel:=ctx.spray as SprayChannel
	channel.set_physics_process(false); channel.held_query=Callable(); channel.aim_query=Callable(); ctx.actions.set_physics_process(false)
	var manager:=actor.skill_manager
	var action:=manager.pool.get_skill("disperse")
	manager.known_actions.disperse=true; manager.equip_slot(0,action)
	var supplies:=manager.combinations.supplies
	var store:=ctx.items
	store.receive("player","venom_extract",2)
	supplies.select_payload(action,"venom",manager)
	check(not manager.use_slot(0,actor,Vector2.RIGHT),"Raw extract was sprayed without a prepared container")
	store.receive("player","venom_sprayer",2)
	var uid:=store.ready_uid("player","venom_sprayer")
	check(store.item(uid).quantity==1 and store.item(uid).properties.doses==3 and store.count("player","venom_sprayer")==2,"Spray bottles stacked or lacked individual capacity")
	var targets: Array[Enemy]=[]
	for i in range(3):
		var target:=game.active_enemies[i]
		target.position=actor.position+[Vector2(85,0),Vector2(-80,0),Vector2(80,90)][i]
		target.process_mode=Node.PROCESS_MODE_INHERIT; target.set_physics_process(false); target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.actor_context.actions.set_physics_process(false)
		target.get_node("BuffManager").clear_all(); target.health_component.invincible=false; targets.append(target)
	await frames()
	var mp:=actor.mana_component.mp
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Spray could not start")
	channel.advance(.24)
	check(actor.mana_component.mp==mp and store.item(uid).properties.doses==3,"Windup consumed a dose")
	channel.advance(.01)
	check(actor.mana_component.mp==mp and store.item(uid).properties.doses==2,"First pulse failed its atomic cost")
	check(targets[0].get_node("BuffManager").has_buff("poison") and not targets[1].get_node("BuffManager").has_buff("poison") and not targets[2].get_node("BuffManager").has_buff("poison"),"Spray cone included actors behind or outside its angle")
	channel.advance(.5); channel.advance(.5)
	check(not channel.active and store.item(uid)==null and store.count("player","venom_sprayer")==1 and actor.mana_component.mp==mp,"Held channel silently opened another bottle or lost pulse costs")
	uid=store.ready_uid("player","venom_sprayer")
	check(manager.use_slot(0,actor,Vector2.RIGHT),"A new press could not open another bottle")
	channel.held_query=func(_binding: String): return false
	channel.advance(.25)
	check(not channel.active and store.item(uid).properties.doses==3,"Releasing during windup still fired")
	channel.held_query=Callable()
	var original:=manager.executor
	var rejecting:=RejectingExecutor.new(); manager.add_child(rejecting); manager.executor=rejecting
	mp=actor.mana_component.mp
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Rejected pulse could not enter windup")
	channel.advance(.25)
	check(not channel.active and actor.mana_component.mp==mp and store.item(uid).properties.doses==3,"Rejected effect charged dose or mana")
	manager.executor=original; rejecting.queue_free()
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Damage interruption could not start")
	actor.health_component.hp-=1; channel.advance(.25)
	check(not channel.active and store.item(uid).properties.doses==3,"Damage did not stop an uncommitted pulse")
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Zero-mana ordinary spray failed to start")
	actor.mana_component.mp=0; channel.advance(.25)
	check(channel.active and actor.mana_component.mp==0 and store.item(uid).properties.doses==2,"Ordinary spray incorrectly required mana or failed its actual dose cost")
	channel.stop()
	# Wall clipping uses the same predicate for actor contacts and residual cells.
	var wall:=StaticBody2D.new(); wall.collision_layer=1; wall.position=actor.position+Vector2(50,0)
	var collision:=CollisionShape2D.new(); var rect:=RectangleShape2D.new(); rect.size=Vector2(16,140); collision.shape=rect; wall.add_child(collision); game.region_root.add_child(wall)
	targets[0].get_node("BuffManager").clear_all(); targets[0].health_component.invincible=false
	await frames()
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Wall clipping check could not start")
	channel.advance(.25); channel.stop()
	check(not targets[0].get_node("BuffManager").has_buff("poison"),"Spray hit through a static wall")
	wall.queue_free(); await frames()
	var paralysis:=load("res://content/spell_operations/statuses/paralysis.tres") as Buff
	var buffs:=targets[0].get_node("BuffManager") as BuffManager
	buffs.clear_all(); buffs.apply_buff(paralysis)
	buffs.tick(1); check(not buffs.apply_buff(paralysis),"Repeated control refreshed an active paralysis")
	buffs.tick(.6); check(not buffs.prevents_actions() and not buffs.apply_buff(paralysis),"Post-control immunity allowed an immediate stun lock")
	buffs.tick(2); check(buffs.apply_buff(paralysis),"Control recovery immunity never expired")
	var snapshot:=game.session.snapshot()
	check(store.valid_definitions(snapshot.inventory),"Partial spray bottles failed inventory validation")
	check(supplies.recycle_preview("venom_sprayer").is_empty(),"Partial sprayer recycled into a full raw extract")
	# An independent target proves charged radius affects real coverage and draw.
	store.receive("player","water_sprayer",1);store.receive("player","frost_salt",2)
	var water_uid:=store.ready_uid("player","water_sprayer")
	supplies.select_payload(action,"water",manager,water_uid)
	supplies.configure_modifier(action,"")
	targets[0].position=actor.position+Vector2(135,0)
	(targets[0].get_node("BuffManager") as BuffManager).clear_all()
	await frames()
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Ordinary range comparison could not start")
	channel.advance(.25);channel.stop()
	check(not targets[0].get_node("BuffManager").has_buff("washing"),"Base 120-range spray reached the independent 135-distance target")
	check(Awake.awaken(actor),"Could not establish explicit awakened reinforcement fixture")
	supplies.configure_modifier(action,"frost_salt")
	var reinforced:=manager.combinations.preview(action,actor)
	mp=actor.mana_component.mp
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Explicit radius reinforcement could not start")
	channel.advance(.25)
	check(targets[0].get_node("BuffManager").has_buff("washing") and is_equal_approx(channel._display_plan.delivery_reach,150.0),"Radius reinforcement was charged without expanding actual/drawn coverage to 150")
	check(actor.mana_component.mp==mp-reinforced.cost and int(store.item(water_uid).properties.doses)==1,"Reinforced coverage did not commit exactly one pulse")
	channel.stop()
	supplies.configure_modifier(action,"frost_salt")
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Global modifier invalidation fixture could not start")
	supplies.configure_modifier(action,"")
	channel.advance(.25)
	check(not channel.active and channel.last_reason.contains("修饰") and int(store.item(water_uid).properties.doses)==1,"Changing a legacy global modifier silently replaced the held spray intent")
	check(manager.use_slot(0,actor,Vector2.RIGHT),"Empower-intent comparison fixture could not start")
	check(not channel.start(action,"slot_0",Vector2.RIGHT,{},true) and not channel.empower,"An active ordinary spray accepted a different magical empowerment intent")
	channel.stop()
	await fixture.close()
	if failures.is_empty(): print("PASS spray channel: real per-UID doses, held input, pulse costs, cone and wall clipping, interruptions, no automatic reload and control recovery")
	quit(0 if failures.is_empty() else 1)
