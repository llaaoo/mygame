class_name ServiceNPC
extends SharedActor
## A service is a capability of a normal actor, not a second NPC gameplay model.
var schedule: NPCSchedule
var locations: Dictionary={}
var hour_query: Callable
var service_request: Callable
var notify: Callable
var lookup_actor: Callable
var _clock := 0.0
var working := true
var _destination:=Vector2.ZERO
func _ready() -> void:
	super._ready()
	add_to_group("interactable")
	var interaction:=Interactable.new()
	interaction.name="Interactable"
	interaction.set_callback(func(visitor: Node2D):
		if can_serve(visitor):
			if service_request.is_valid(): service_request.call()
		elif notify.is_valid(): notify.call("训练师正在休息或对你抱有敌意。服务时间：06:00—22:00。"))
	add_child(interaction)
func can_serve(visitor: Node2D) -> bool:
	if health_component.is_dead or not working or not actor_context or not is_instance_valid(visitor) or visitor.position.distance_to(position)>=80: return false
	var context:=visitor.get("actor_context") as ActorContext
	return not context or actor_context.relations.attitude(actor_context.id,context.id)!="hostile"
func _physics_process(delta: float) -> void:
	if not actor_context or health_component.is_dead: return
	_clock-=delta
	if _clock>0: return
	_clock=.25
	if hour_query.is_valid() and schedule:
		var entry:=schedule.get_entry_for_hour(float(hour_query.call()))
		working=entry and entry.target_marker=="work"
		if entry and locations.has(entry.target_marker): _destination=locations[entry.target_marker]
	var target: Node2D=lookup_actor.call("player") if lookup_actor.is_valid() else null
	if target and actor_context.relations.attitude(actor_context.id,"player")=="hostile":
		working=false
		if target.position.distance_to(position)<56:
			var hit:=Action.melee(self); hit.direction=(target.position-position).normalized()
			actor_context.actions.try_action(hit)
		elif target.position.distance_to(position)<400:
			actor_context.actions.try_action(Action.move(actor_context.region.navigation.direction(position,target.position),self))
		return
	if _destination.distance_to(position)>30 and actor_context.region.navigation:
		actor_context.actions.try_action(Action.move(actor_context.region.navigation.direction(position,_destination),self))
	else: actor_context.actions.try_action(Action.move(Vector2.ZERO,self))

func resume_schedule() -> void:
	if actor_context and actor_context.relations.attitude(actor_context.id,"player")=="hostile": working=false; return
	if not hour_query.is_valid() or not schedule or health_component.is_dead: return
	var entry:=schedule.get_entry_for_hour(float(hour_query.call()))
	working=entry and entry.target_marker=="work"
	if entry and locations.has(entry.target_marker):
		_destination=locations[entry.target_marker]
		position=_destination
