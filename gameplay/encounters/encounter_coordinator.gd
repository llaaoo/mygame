class_name EncounterCoordinator
extends RefCounted
## Region-scoped weak roster. Alarm messages carry a past position, never a live target tracker.
var _roster: Array[WeakRef]=[]
func register(context: ActorContext,rules: EncounterTactics) -> EnemyAwareness:
	var awareness:=EnemyAwareness.new(context,rules,self);_roster.append(weakref(awareness));return awareness
func clear() -> void:_roster.clear()
func alarm(source: EnemyAwareness,point: Vector2) -> void:
	var body:=source.actor()
	if not body:return
	for handle in _roster:
		var other:=handle.get_ref() as EnemyAwareness
		var ally:=other.actor() if other else null
		if not ally or other==source or ally.health_component.is_dead or ally.actor_context.encounter_group.is_empty() or ally.actor_context.encounter_group!=body.actor_context.encounter_group:continue
		if body.position.distance_to(ally.position)<=source.rules.alarm_radius and body.can_see(ally):other.receive_alarm(point)
func cover_position(context: ActorContext,target: Node2D) -> Vector2:
	if not context.awareness or context.awareness.rules.role!=EncounterTactics.Role.BULWARK:return Vector2.INF
	var body:=context.actor as Enemy
	for handle in _roster:
		var state:=handle.get_ref() as EnemyAwareness
		var ally:=state.actor() if state else null
		if not ally or ally==body or ally.health_component.is_dead or ally.actor_context.encounter_group!=context.encounter_group or state.rules.role!=EncounterTactics.Role.SKIRMISHER or not body.can_see(ally):continue
		var actions:=ally.actor_context.actions;var weapon:=actions.attack_moveset()
		var armed: bool=weapon!=null and weapon.weapon_type=="bow" and context.items.can_pay(ally.actor_context.id,{"arrow":1},true)
		if not armed:continue
		if body.position.distance_to(ally.position)>300:continue
		return ally.position+ally.position.direction_to(target.position)*100
	return Vector2.INF
