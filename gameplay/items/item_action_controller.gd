class_name ItemActionController
extends Node2D
## Generic timed item operation; UI and NPCs submit requests to this same boundary.
var context: ActorContext
var aim_query: Callable
var projectile_factory: Callable
var uid := ""
var weapon_uid := ""
var profile: ItemUseDefinition
var remaining := 0.0
var aiming := false
var direction:=Vector2.RIGHT
var origin:=Vector2.ZERO
var hp := 0
var generation := 0
var operation_id := 0
func busy() -> bool: return not uid.is_empty()
func begin(id: String,aim := false,requested_direction:=Vector2.ZERO) -> bool:
	if busy() or context.actions.busy() or not available(): return false
	if context.actor.get_node("SkillManager").combinations.is_busy(): return false
	var source:=context.items.item(id)
	var selected:=id if source else context.items.ready_uid(context.id,id)
	source=context.items.item(selected)
	if not source or context.items.locate(selected)!=context.id+".pocket": return false
	var definition:=context.items.definitions.get(source.definition_id) as ItemData
	if not definition or not definition.use_profile or definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY: return false
	profile=definition.use_profile
	weapon_uid=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	if profile.kind==ItemUseDefinition.Kind.COATING and weapon_uid.is_empty(): return false
	if context.actions.stamina.current<profile.stamina: return false
	uid=selected; origin=context.actor.position; hp=context.actor.get_node("HealthComponent").hp; generation=context.region.generation
	operation_id=context.actions.operation_id
	direction=requested_direction.normalized() if requested_direction.length_squared()>.01 else context.actions.facing
	aiming=aim and profile.kind==ItemUseDefinition.Kind.THROWABLE
	remaining=profile.duration
	context.actions.mode="aim_item" if aiming else "item"
	context.actions.remaining=profile.duration+1
	context.actions.movement=Vector2.ZERO
	context.actions.guarding=false
	queue_redraw()
	return true
func available() -> bool:
	return not get_tree().paused and is_instance_valid(context.actor) and not context.actor.get_node("HealthComponent").is_dead and context.actor.get_node("SkillManager").can_act(context.actor) and context.region.available() and (not "ui_blocked" in context.actor or not context.actor.ui_blocked)
func confirm() -> bool:
	if not aiming: return false
	aiming=false; origin=context.actor.position; context.actions.mode="item"; remaining=profile.duration; queue_redraw()
	return true
func cancel() -> void:
	uid=""; aiming=false
	if context and context.actions and context.actions.mode in ["item","aim_item"]: context.actions.cancel("item_cancelled")
	queue_redraw()
func _input(event: InputEvent) -> void:
	if not aiming: return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		confirm(); context.actions.input_suppressed=.1; get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
		cancel(); context.actions.input_suppressed=.1; get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not busy(): return
	if not available() or not context.region.available(generation) or context.actions.operation_id!=operation_id or context.actor.get_node("HealthComponent").hp<hp or context.items.locate(uid)!=context.id+".pocket": cancel(); return
	if profile.kind==ItemUseDefinition.Kind.COATING and str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))!=weapon_uid: cancel(); return
	if aiming:
		if aim_query.is_valid():
			var next:=Vector2(aim_query.call())
			if next.is_finite() and next.length_squared()>.01: direction=next.normalized()
		queue_redraw(); return
	if context.actor.position.distance_to(origin)>12: cancel(); return
	remaining-=delta
	if remaining<=0: commit()
func commit() -> bool:
	if not busy() or not available() or not context.region.available(generation) or context.actions.operation_id!=operation_id or context.actor.get_node("HealthComponent").hp<hp or context.items.locate(uid)!=context.id+".pocket": cancel(); return false
	if profile.kind==ItemUseDefinition.Kind.COATING and str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))!=weapon_uid: cancel(); return false
	var plan:=CastPlan.new(); plan.actor=context.actor; plan.action=SkillData.new(); plan.action.operation_id="item_use"; plan.stamina_cost=profile.stamina
	plan.instance_costs=[{"uid":uid,"property":"quantity","amount":1}]
	var supplies: CastingSupplies=context.actor.get_node("SkillManager").combinations.supplies
	var transaction:=CastTransaction.new(context.actor,supplies,CastTransaction.allocate_id())
	if not transaction.reserve(plan): transaction.rollback(); cancel(); return false
	if profile.kind==ItemUseDefinition.Kind.COATING:
		var weapon:=context.items.item(weapon_uid)
		if not weapon: transaction.rollback(); cancel(); return false
		var props:=weapon.properties.duplicate(true); props.coating={"id":profile.id,"expires_at":context.items.clock_seconds+profile.coating_seconds}
		context.items.set_properties(weapon_uid,props)
	else:
		var projectile: ThrownDose=projectile_factory.call() if projectile_factory.is_valid() else ThrownDose.new()
		if not is_instance_valid(projectile): transaction.rollback(); cancel(); return false
		projectile.actor_context=context; projectile.profile=profile; projectile.direction=direction; projectile.remaining=profile.reach
		projectile.excluded=[context.actor.get_rid()]; context.region.root.add_child(projectile); projectile.global_position=context.actor.global_position
	transaction.commit()
	context.facts.publish("item_action_committed",context.id,{"item":profile.id,"weapon_uid":weapon_uid})
	cancel()
	if profile.kind==ItemUseDefinition.Kind.THROWABLE: context.actions.mode="recovery"; context.actions.remaining=.4
	return true
func _draw() -> void:
	if not aiming or not context: return
	var endpoint:=direction*profile.reach
	var ray:=PhysicsRayQueryParameters2D.create(context.actor.global_position,context.actor.global_position+endpoint,1,[context.actor.get_rid()])
	var hit:=get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): endpoint=Vector2(hit.position)-context.actor.global_position
	draw_dashed_line(Vector2.ZERO,endpoint,Color("d4c080"),2,12)
	draw_arc(endpoint,profile.splash_radius,0,TAU,32,Color("d4c080"),1)
