extends SceneTree
## Controlled actor/position and explicit clocks isolate the input handoff;
## normal-AI/real-input coverage is separate from this lifecycle regression.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot()
	var enemy:=game.active_enemies[0] as Enemy
	var actions:=enemy.actor_context.actions
	var store:=game.session.inventory
	enemy.process_mode=Node.PROCESS_MODE_INHERIT
	enemy.set_process(false);enemy.state_chart.process_mode=Node.PROCESS_MODE_DISABLED
	enemy.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	await physics_frame
	enemy.position=Vector2(-4000,800);enemy._home_position=enemy.position
	game.player.position=Vector2(-3500,800)
	actions.cancel();actions.stamina.current=actions.stamina.maximum
	var guard:=Action.new();guard.action_type=Action.ActionType.GUARD;guard.params["held"]=true;guard.direction=Vector2.RIGHT
	check(actions.try_action(guard).accepted and actions.guarding,"Real guard request did not start")
	check(actions.try_action(Action.move(Vector2.RIGHT,enemy)).accepted,"Could not establish previous controller movement")
	check(actions.stamina.spend(30),"Could not establish paid stamina use")
	var spent:=actions.stamina.current
	enemy._begin_return_home()
	check(not actions.guarding and actions.movement.is_zero_approx(),"Disengagement retained held guard or old movement")
	actions.advance(1.2)
	check(actions.stamina.current>spent,"Disengaged actor did not recover under its actual stamina rules")
	# The idle adapter must also relinquish a previous search direction.
	actions.try_action(Action.move(Vector2.RIGHT,enemy))
	enemy._returning_home=false;enemy.patrol_enabled=false
	enemy._tick_idle_navigation(.1)
	check(actions.movement.is_zero_approx(),"Quiet navigation retained the last search input")
	# Changing controller intent cannot cancel a committed shot or refund costs.
	check(store.receive(enemy.actor_context.id,"river_bow",1)==1,"Bow fixture could not be received")
	check(store.equip(enemy.actor_context.id,store.find_owned(enemy.actor_context.id,"river_bow")).accepted,"Bow fixture could not be equipped")
	check(store.receive(enemy.actor_context.id,"arrow",2)==2,"Arrow fixture could not be received")
	actions.cancel();actions.stamina.current=actions.stamina.maximum
	var shot:=Action.melee(enemy);shot.direction=Vector2.RIGHT
	check(actions.try_action(shot).accepted and actions.mode=="attack","Paid shot did not begin")
	var cost_after:=actions.stamina.current;var remaining:=actions.remaining;var token:=actions.operation_id
	var arrows:=store.count(enemy.actor_context.id,"arrow")
	enemy._begin_return_home()
	check(actions.mode=="attack" and actions.operation_id==token and is_equal_approx(actions.remaining,remaining) and is_equal_approx(actions.stamina.current,cost_after),"Return cancelled or refunded an already committed physical attack")
	actions.advance(actions.profile.windup+.01)
	check(store.count(enemy.actor_context.id,"arrow")==arrows-1,"Committed shot lost its captured real ammunition on disengagement")
	actions.advance(remaining+1)
	check(actions.mode=="idle" and store.count(enemy.actor_context.id,"arrow")==arrows-1,"Return replayed the shot or prevented recovery")
	await fixture.close()
	if failures.is_empty():print("PASS enemy disengagement: release old guard/search input, restore stamina recovery, preserve paid attack clock and one real arrow release; controlled lifecycle fixture")
	quit(0 if failures.is_empty() else 1)
