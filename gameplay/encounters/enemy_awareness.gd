class_name EnemyAwareness
extends RefCounted
var rules: EncounterTactics
var _context: WeakRef
var coordinator: EncounterCoordinator
var phase := "quiet"
var last_seen:=Vector2.INF
var remaining := 0.0
var _warning := 0.0
var _clock := 0.0
var _elapsed := 0.0
func _init(context: ActorContext,definition: EncounterTactics,owner: EncounterCoordinator) -> void:
	_context=weakref(context);rules=definition;coordinator=owner
func actor() -> Enemy:
	var context:=_context.get_ref() as ActorContext
	return context.actor as Enemy if context and is_instance_valid(context.actor) else null
func advance(delta: float) -> void:
	var body:=actor()
	if not body or body.health_component.is_dead or not body.actor_context.region.available():return
	remaining=maxf(0,remaining-delta);_clock-=delta;_elapsed+=delta
	if _clock>0:return
	var elapsed:=_elapsed;_elapsed=0;_clock=.1
	var target:=body.player
	var visible: bool=is_instance_valid(target) and not target.health_component.is_dead and not body.story_truce and body.actor_context.relations.attitude(body.actor_context.id,"player")=="hostile" and body.can_see(target)
	var distance:=body._home_position.distance_to(target.position) if visible else INF
	if phase in ["engaged","search"]:
		if visible and distance<=body._leash_distance:
			last_seen=target.position;body._last_seen_position=last_seen;remaining=rules.search_seconds;phase="engaged"
		else:phase="search"
		if remaining<=0:phase="quiet";last_seen=Vector2.INF
		return
	if visible and distance<=rules.warning_radius:
		if phase!="warning":
			phase="warning";_warning=rules.warning_seconds
			body.actor_context.facts.publish("territory_warning",body.actor_context.id,{"position":[body.position.x,body.position.y],"seconds":rules.warning_seconds})
		_warning=maxf(0,_warning-elapsed)
		if distance<=rules.defend_radius or _warning<=0:provoke(target.position)
	else:
		phase="quiet";_warning=0
func provoke(point: Vector2) -> void:
	if not point.is_finite():return
	var body:=actor()
	if not body or body.story_truce:return
	var fresh:=phase not in ["engaged","search"]
	last_seen=point;remaining=rules.search_seconds;phase="search"
	body._last_seen_position=point
	if fresh:
		body.actor_context.facts.publish("territory_alarm",body.actor_context.id,{"position":[point.x,point.y]})
		coordinator.alarm(self,point)
func receive_alarm(point: Vector2) -> void:
	var body:=actor()
	if not body or body.story_truce:return
	last_seen=point;remaining=rules.search_seconds;phase="search";body._last_seen_position=point
func visible_target() -> Node2D:
	var body:=actor()
	if phase not in ["engaged","search"] or not body or not is_instance_valid(body.player):return null
	if body.player.health_component.is_dead or body.story_truce or body.actor_context.relations.attitude(body.actor_context.id,"player")!="hostile":return null
	return body.player if body.can_see(body.player) and body._home_position.distance_to(body.player.position)<=body._leash_distance else null
func search_direction() -> Vector2:
	var body:=actor()
	if phase!="search" or not last_seen.is_finite() or not body or not body.actor_context.region.navigation:return Vector2.ZERO
	return body.actor_context.region.navigation.direction(body.position,last_seen) if body.position.distance_to(last_seen)>24 else Vector2.ZERO
func caption() -> String:
	return "领地警告 · 离开可避免交战" if phase=="warning" else "警戒搜索 · 最后目击位置" if phase=="search" else "已警报 · 同营地协同" if phase=="engaged" else "领地 · 留意警告与同伴"
