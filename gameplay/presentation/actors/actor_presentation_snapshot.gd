class_name ActorPresentationSnapshot
extends RefCounted
## Read-only bridge from capabilities to animation semantics; never executes an action.
static func capture(actor: CharacterBody2D) -> Dictionary:
	var context: ActorContext=actor.get("actor_context") if "actor_context" in actor else null
	var direction:=context.actions.facing if context and context.actions else Vector2(actor.get("facing_direction")) if "facing_direction" in actor else Vector2.DOWN
	var health:=actor.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_dead: return {"state":"death","phase":"whole","direction":direction,"token":"death"}
	if context and context.actions:
		var physical:=context.actions.presentation_snapshot()
		if not physical.is_empty(): return physical
	if context and context.item_actions and context.item_actions.busy():
		var use: ItemActionController=context.item_actions
		return {"state":"aim" if use.aiming else "throw" if use.profile.kind==ItemUseDefinition.Kind.THROWABLE else "use","phase":"whole","progress":0.0 if use.aiming else 1-use.remaining/maxf(.001,use.profile.duration),"direction":use.direction,"token":"item:"+use.uid}
	if context and context.spray and context.spray.active:
		return {"state":"spray","phase":"loop","direction":context.spray.direction,"token":"spray:"+context.spray.uid}
	var manager:=actor.get_node_or_null("SkillManager") as SkillManager
	if manager and manager.combinations and not manager.combinations.pending.is_empty():
		var plan: CastPlan=manager.combinations.pending
		return {"state":"cast","phase":"windup","progress":1-plan.remaining/maxf(.001,plan.preparation),"direction":plan.direction,"token":"prepare:"+str(plan.execution_id)}
	if "casting" in actor and actor.get("casting"):
		var casting: PlayerCastingController=actor.get("casting")
		var cast:=casting.presentation_snapshot()
		if not cast.is_empty(): return cast
	if context and context.preparation_query.is_valid() and context.preparation_query.call(): return {"state":"cast","phase":"loop","direction":direction,"token":"prepare"}
	if context and context.actions and context.actions.guarding: return {"state":"guard","phase":"whole","progress":.5,"direction":direction,"token":"guard"}
	if actor.velocity.length_squared()>1: return {"state":"sprint" if context and context.actions and context.actions.sprinting else "walk","phase":"loop","direction":actor.velocity.normalized(),"token":"walk"}
	return {"state":"idle","phase":"loop","direction":direction,"token":"idle"}
