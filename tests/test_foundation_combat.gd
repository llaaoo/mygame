extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=3) -> void:
	for i in range(n): await process_frame
func run() -> void:
	var fixture:=Fixture.new(self)
	var game:=await fixture.boot()
	var player:=game.player
	var controls:=player.actor_context.actions
	player.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var target:=game.active_enemies[0]
	player.position=Vector2(-3500,2000); target.position=player.position+Vector2(40,0)
	target.health_component.hp=target.health_component.max_hp
	await frames()
	var attack:=Action.melee(player); attack.direction=Vector2.RIGHT
	var hp:=target.health_component.hp
	check(controls.try_action(attack).accepted and controls.stamina.current==88,"Physical attack did not spend stamina at acceptance")
	check(not controls.contact(target).accepted and target.health_component.hp==hp,"Weapon hit before windup")
	controls.elapsed=.2
	var hit:=controls.contact(target)
	check(hit.accepted and hit.damage_dealt>0 and hit.impact_applied==20,"Shared physical hit did not resolve damage and impact")
	check(not controls.contact(target).accepted,"Same swing hit the same target twice")
	controls.cancel()
	controls.stamina.current=5
	check(not controls.try_action(attack).accepted and controls.stamina.current==5,"Rejected action spent stamina")
	controls.stamina.advance(1.8)
	check(controls.stamina.current>5,"Exhausted actor cannot recover")
	controls.stamina.current=100
	var dodge:=Action.dodge(Vector2.LEFT,player)
	check(controls.try_action(dodge).accepted and controls.stamina.current==80,"Dodge did not consume shared resource")
	controls.elapsed=.12
	var avoided:=CombatExecutor.report_hit(target,player,10,player.position,null,["melee"],"dodge-test",20)
	check(not avoided.accepted and avoided.rejection=="dodge","Dodge window did not reject direct contact")
	controls.cancel()
	# Grant a real shield, then equip its instance through the normal service.
	game.session.inventory.receive("player","river_shield",1)
	target.position=player.position+Vector2(1000,0)
	check(game.equipment_service.equip("river_shield"),"Real shield could not equip in calm area")
	target.position=player.position+Vector2(40,0)
	var guard:=Action.new(); guard.action_type=Action.ActionType.GUARD; guard.params["held"]=true; guard.direction=Vector2.RIGHT
	controls.try_action(guard)
	controls.stamina.current=100
	player.health_component.invincible=false
	var before:=player.health_component.hp
	hit=CombatExecutor.report_hit(target,player,15,player.position,null,["melee"],"guard-test",20)
	check(hit.blocked and hit.damage_dealt==0 and player.health_component.hp==before and controls.stamina.current==92,"Frontal shield block did not trade impact for stamina")
	target.position=player.position+Vector2(-40,0)
	player.health_component.invincible=false
	hit=CombatExecutor.report_hit(target,player,15,player.position,null,["melee"],"rear-test",20)
	check(not hit.blocked and hit.damage_dealt>0,"Guard blocked a rear hit")
	player.health_component.invincible=false
	target.position=player.position+Vector2(40,0)
	controls.cancel(); controls.stamina.current=1; controls.try_action(guard)
	hit=CombatExecutor.report_hit(target,player,10,player.position,null,["melee"],"break-test",40)
	check(hit.guard_broken and controls.mode=="stagger" and controls.stamina.current==0,"Insufficient stamina did not break guard")
	controls.cancel(); controls.stability.current=10; controls.stability.grace=0
	player.health_component.invincible=false
	hit=CombatExecutor.report_hit(target,player,1,player.position,null,["melee"],"knockdown",20)
	check(controls.mode=="stagger" and controls.remaining==1,"Impact depletion did not cause knockdown")
	controls.advance(1)
	check(controls.stability.current==100 and controls.stability.grace>0,"Knockdown recovery did not prevent endless stagger")
	# Physical parameters and input policy are data, independent of player/enemy scripts.
	var heavy:=Action.melee(player); heavy.action_type=Action.ActionType.HEAVY_ATTACK; heavy.direction=Vector2.RIGHT
	controls.stamina.current=100
	check(controls.try_action(heavy).accepted and controls.profile.damage_multiplier==1.5 and controls.stamina.current==76,"Heavy attack did not use profile costs")
	controls.cancel()
	await fixture.close()
	if failures.is_empty(): print("PASS foundation combat: acceptance costs, windup, one-hit family, dodge, facing guard, guard break and impact recovery")
	quit(0 if failures.is_empty() else 1)
