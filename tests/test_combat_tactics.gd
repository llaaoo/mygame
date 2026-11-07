extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=3) -> void:
	for i in range(n): await physics_frame
func reset_actor(actor: CharacterBody2D) -> void:
	var actions: ActorActionController=actor.actor_context.actions
	actions.cancel(); actions.stamina.current=100; actions.stability.current=100; actions.stability.grace=0
	actor.get_node("HealthComponent").invincible=false
	actor.get_node("HealthComponent").max_hp=500; actor.get_node("HealthComponent").hp=500
func strike(actor: Player,target: Enemy,id: String) -> HitResult:
	var actions:=actor.actor_context.actions
	actions.cancel(); actions.stamina.current=100
	actor.actor_context.martial.learn(id); actor.actor_context.martial.ready_at.clear()
	var request:=Action.new(); request.action_type=Action.ActionType.TECHNIQUE; request.skill_id=id; request.direction=Vector2.RIGHT
	check(actions.try_action(request).accepted,"Technique refused: "+id)
	actions.elapsed=actions.profile.windup+.01
	return actions.contact(target)
func run() -> void:
	var fixture:=Fixture.new(self)
	var game:=await fixture.boot(true)
	var actor:=game.player
	var actions:=actor.actor_context.actions
	var store:=game.session.inventory
	actor.position=Vector2(-3059,-1210)
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var target:=game.active_enemies[0]
	target.position=actor.position+Vector2(40,0)
	var defender:=target.actor_context.actions
	for id in ["river_sabre","river_spear","river_staff","river_shield","river_foreman_coat","river_boots"]: store.receive("player",id,1)
	store.receive(target.actor_context.id,"river_shield",1); store.receive(target.actor_context.id,"river_sabre",1)
	store.equip(target.actor_context.id,store.find_owned(target.actor_context.id,"river_sabre")); store.equip(target.actor_context.id,store.find_owned(target.actor_context.id,"river_shield"))
	var guard:=Action.new(); guard.action_type=Action.ActionType.GUARD; guard.params["held"]=true; guard.direction=Vector2.LEFT
	reset_actor(target); defender.stamina.current=32; defender.try_action(guard)
	store.equip("player",store.find_owned("player","river_sabre"))
	var mp:=actor.mana_component.mp
	var result:=strike(actor,target,"blade_breaker")
	check(result.guard_broken and not result.blocked and defender.stamina.current==0 and defender.mode=="stagger","Breaker did not punish a real shield's stamina")
	check(actor.mana_component.mp==mp,"Physical utility consumed magic resources")
	# The same pressure cannot bypass an actual dodge.
	reset_actor(target)
	check(defender.try_action(Action.dodge(Vector2.UP,target)).accepted,"Target dodge refused")
	var dodge_stamina:=defender.stamina.current
	defender.elapsed=.12
	result=strike(actor,target,"blade_breaker")
	check(result.rejection=="dodge" and defender.stamina.current==dodge_stamina and not result.guard_broken,"Breaker ignored dodge or charged guard costs")
	# Spear commits through the common hit chain and interrupts actual item preparation.
	reset_actor(target); store.equip("player",store.find_owned("player","river_spear"))
	if not store.can_pay(target.actor_context.id,{"poison_rag":1},true): store.receive(target.actor_context.id,"poison_rag",1)
	var rags:=store.count(target.actor_context.id,"poison_rag")
	check(target.actor_context.item_actions.begin("poison_rag"),"Target could not prepare a real coating")
	result=strike(actor,target,"spear_thrust")
	check(result.interrupted and defender.mode=="stagger" and not target.actor_context.item_actions.busy() and store.count(target.actor_context.id,"poison_rag")==rags,"Thrust failed to interrupt preparation or consumed cancelled item")
	reset_actor(target)
	var completed: Array[int]=[0]
	check(target.attack_preparation.begin(actor,Vector2.LEFT,1.0,0,func(): completed[0]+=1,"ranged"),"Legacy ranged warning could not begin")
	result=strike(actor,target,"spear_thrust")
	target.attack_preparation.tick(2)
	check(result.interrupted and completed[0]==0 and not target.attack_preparation.busy(),"Physical interrupt left a legacy ranged callback armed")
	# Staff push is a qualified effect, suppressed by shields and invincibility.
	reset_actor(target); defender.try_action(guard); store.equip("player",store.find_owned("player","river_staff"))
	result=strike(actor,target,"staff_sweep")
	check(result.blocked and not result.pushed and defender._push_remaining==0,"Blocked sweep pushed through a shield")
	reset_actor(target); target.health_component.invincible=true
	result=strike(actor,target,"staff_sweep")
	check(not result.accepted and not result.pushed,"Invincibility still received push")
	reset_actor(target)
	target.process_mode=Node.PROCESS_MODE_INHERIT; target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; target.set_process(false); target.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var wall:=StaticBody2D.new(); wall.collision_layer=1
	var collider:=CollisionShape2D.new(); var box:=RectangleShape2D.new(); box.size=Vector2(8,100); collider.shape=box; wall.add_child(collider); wall.position=target.position+Vector2(38,0); game.region_root.add_child(wall)
	await frames()
	var old:=target.position
	result=strike(actor,target,"staff_sweep")
	defender.advance(.18)
	check(result.pushed and target.position.x>old.x and target.position.x<old.x+38,"Sweep did not produce wall-limited physical displacement")
	wall.queue_free(); await frames()
	# A precise block earns one manual follow-up and cannot be farmed by guard polling.
	target.position=actor.position+Vector2(40,0)
	store.equip("player",store.find_owned("player","river_sabre")); store.equip("player",store.find_owned("player","river_shield"))
	reset_actor(actor); actions.parry_retry=0; guard.direction=Vector2.RIGHT; actions.try_action(guard)
	var serial:=actions._attack_sequence
	result=CombatExecutor.report_hit(target,actor,10,actor.position,null,["melee","physical"],"precise.1",20)
	check(result.parried and actions.counter_remaining>0 and actions._attack_sequence==serial,"Precise block did not leave a manual counter opportunity")
	guard.params.held=false; actions.try_action(guard); guard.params.held=true; actions.try_action(guard)
	actor.health_component.invincible=false
	result=CombatExecutor.report_hit(target,actor,10,actor.position,null,["melee","physical"],"precise.2",20)
	check(result.blocked and not result.parried,"Rapid guard toggling bypassed the precision retry interval")
	var request:=Action.melee(actor); request.direction=Vector2.RIGHT
	check(actions.try_action(request).accepted and actions.counter_strike and actions.counter_remaining==0 and actions.profile.damage_multiplier>1,"Manual counter did not consume its earned opportunity")
	check(load("res://content/weapons/blade.tres").attacks[0].damage_multiplier==1,"Counter modified a shared moveset")
	actions.cancel(); actions.counter_remaining=.1; actions.advance(.11)
	check(actions.counter_remaining==0,"Counter window did not expire in live time")
	# Real gear changes control resistance and action economy without fake copies.
	store.equip("player",store.find_owned("player","river_foreman_coat"))
	reset_actor(actor); actions.stamina.current=50; actions.stamina.delay=0; actions.advance(1)
	check(is_equal_approx(actions.stamina.current,58),"Heavy coat has no stamina-recovery tradeoff")
	var heavy:=AttackProfile.new(); heavy.impact=50
	actor.health_component.invincible=false
	result=CombatExecutor.report_hit(target,actor,1,actor.position,null,["physical"],"armour.1",50,heavy)
	check(is_equal_approx(result.impact_applied,40),"Heavy armour did not resist incoming impact")
	store.equip("player",store.find_owned("player","river_boots"))
	reset_actor(actor)
	check(actions.try_action(Action.dodge(Vector2.UP,actor)).accepted and actions.stamina.current==82,"Light boots did not change actual dodge cost")
	# A committed physical action cannot silently switch its weapon source.
	actions.cancel(); actions.stamina.current=100
	store.equip("player",store.find_owned("player","river_sabre"))
	check(actions.try_action(request).accepted,"Could not begin source-bound attack")
	store.equip("player",store.find_owned("player","river_spear"))
	check(not actions.contact(target).accepted,"Stale weapon source could contact before the next physics tick")
	actions.advance(.01)
	check(actions.mode=="idle","Replacing a committed weapon left its old strike active")
	game._save_progress()
	await fixture.close()
	if failures.is_empty(): print("PASS combat tactics: guard pressure, real preparation interruption, qualified wall-limited push, timed manual counter and actual gear tradeoffs")
	quit(0 if failures.is_empty() else 1)
