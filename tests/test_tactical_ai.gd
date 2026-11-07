extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
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
	actor.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
	var foe:=game.active_enemies[0]
	var ally:=game.active_enemies[1]
	var actions:=foe.actor_context.actions
	var store:=game.session.inventory
	actor.position=Vector2(-3059,-1210); foe.position=actor.position+Vector2(50,0); ally.position=actor.position+Vector2(300,0)
	for other in [foe,ally]:
		other.process_mode=Node.PROCESS_MODE_INHERIT; other.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; other.set_process(false); other.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
		other.actor_context.actions.cancel(); other.actor_context.actions.stamina.current=100
		store.receive(other.actor_context.id,"river_sabre",1); store.equip(other.actor_context.id,store.find_owned(other.actor_context.id,"river_sabre"))
	store.receive("player","river_sabre",1); store.equip("player",store.find_owned("player","river_sabre"))
	await frames()
	var hit:=Action.melee(actor); hit.action_type=Action.ActionType.HEAVY_ATTACK; hit.direction=Vector2.RIGHT
	check(actor.actor_context.actions.try_action(hit).accepted,"Could not create observable heavy windup")
	var brain:=EnemyCharacterBrain.new(foe)
	var chosen:=brain.choose(actor)
	check(chosen.is_empty() and actions.mode=="idle","AI reacted before its observation delay")
	brain.tick(.3); chosen=brain.choose(actor)
	check(chosen.size()==1 and chosen[0].action_type==Action.ActionType.DODGE,"AI did not react after seeing enough of the heavy windup")
	if not chosen.is_empty(): foe.resolve_action(chosen[0])
	check(actions.mode=="dodge" and actions.stamina.current<100,"AI dodge was free or never executed")
	# New fake windup during cooldown does not trigger an automatic second defense.
	actions.cancel(); actor.actor_context.actions.cancel(); actor.actor_context.actions.stamina.current=100
	actor.actor_context.actions.try_action(hit)
	brain.tick(.3); chosen=brain.choose(actor); brain.tick(.3); chosen=brain.choose(actor)
	check(not chosen.any(func(action): return action.action_type in [Action.ActionType.GUARD,Action.ActionType.DODGE]),"AI spammed defense through its cooldown")
	actor.actor_context.actions.cancel(); actions.cancel(); actions.stamina.current=10
	brain=EnemyCharacterBrain.new(foe)
	chosen=brain.choose(actor)
	check(chosen.size()==1 and chosen[0].action_type==Action.ActionType.MOVE and chosen[0].direction.dot((actor.position-foe.position).normalized())<0,"Exhausted AI tried to trade attacks instead of recovering")
	# An ally in a visible committed swing owns this close-range opening.
	actions.cancel(); actions.stamina.current=100
	ally.position=actor.position+Vector2(0,45)
	var ally_attack:=Action.melee(ally); ally_attack.direction=(actor.position-ally.position).normalized()
	check(ally.actor_context.actions.try_action(ally_attack).accepted,"Ally physical attack could not commit")
	brain=EnemyCharacterBrain.new(foe)
	await frames()
	chosen=brain.choose(actor)
	check(chosen.size()==1 and chosen[0].action_type==Action.ActionType.MOVE,"Small squad ignored another ally's actual swing")
	# After own recovery there is a deliberate gap before another strike.
	ally.actor_context.actions.cancel(); ally.position+=Vector2(400,0)
	actions.cancel(); actions.stamina.current=100
	var own:=Action.melee(foe); own.direction=(actor.position-foe.position).normalized()
	check(actions.try_action(own).accepted,"Could not begin own strike")
	brain.tick(.01)
	actions.advance(actions.remaining+.01)
	brain._clock=0
	chosen=brain.choose(actor)
	check(not chosen.any(func(action): return action.action_type in [Action.ActionType.MELEE,Action.ActionType.HEAVY_ATTACK]),"AI did not leave its advertised recovery opening")
	# Definition timing is shared and immutable; observations are per-brain.
	var separate:=EnemyCharacterBrain.new(foe)
	check(separate._defense_cooldown==0 and separate._observation_age==0,"Separate brains shared cooldown/observation state")
	var invalid:=CombatTemperament.new(); invalid.reaction_delay=-1
	check(not invalid.valid(),"Invalid reaction data accepted")
	await fixture.close()
	if failures.is_empty(): print("PASS tactical AI: visible observation delay, defense cooldown, real dodge, stamina retreat, squad spacing and recovery gaps")
	quit(0 if failures.is_empty() else 1)
