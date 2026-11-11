class_name ItemActionController
extends Node2D
## Generic timed item operation; UI and NPCs submit requests to this same boundary.
var context: ActorContext
var aim_query: Callable
var projectile_factory: Callable
var input_source := ""
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
var last_reason := ""
func busy() -> bool: return not uid.is_empty()
func begin(id: String,aim := false,requested_direction:=Vector2.ZERO,shortcut_source := "") -> bool:
	return begin_result(id,aim,requested_direction,shortcut_source).accepted
func begin_result(id: String,aim := false,requested_direction:=Vector2.ZERO,shortcut_source := "") -> OperationResult:
	last_reason=""
	if busy() or context.actions.busy(): return _refuse("当前动作尚未结束")
	if not available(): return _refuse("当前无法使用物品")
	if context.actor.get_node("SkillManager").combinations.is_busy(): return _refuse("正在准备法术")
	var source:=context.items.item(id)
	var selected:=id if source else context.items.ready_uid(context.id,id)
	source=context.items.item(selected)
	if not source: return _refuse("所选物品已耗尽或不在口袋中")
	if context.items.locate(selected)!=context.id+".pocket": return _refuse("所选实物不在口袋中")
	var definition:=context.items.definitions.get(source.definition_id) as ItemData
	if not definition or not definition.use_profile or definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY: return _refuse("此物品不能这样使用")
	profile=definition.use_profile
	if profile.kind==ItemUseDefinition.Kind.BOOK:
		var reason:=_book_reason()
		if not reason.is_empty(): return _refuse(reason)
	weapon_uid=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	if profile.kind==ItemUseDefinition.Kind.COATING and weapon_uid.is_empty(): return _refuse("涂附需要主手武器")
	if context.actions.stamina.current<profile.stamina: return _refuse("体力不足")
	input_source=shortcut_source
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
	return OperationResult.success()
func _refuse(reason: String) -> OperationResult:
	last_reason=reason
	return OperationResult.reject(reason)
func available() -> bool:
	return not get_tree().paused and is_instance_valid(context.actor) and not context.actor.get_node("HealthComponent").is_dead and context.actor.get_node("SkillManager").can_act(context.actor) and context.region.available() and (not "ui_blocked" in context.actor or not context.actor.ui_blocked)
func confirm() -> bool:
	if not aiming: return false
	aiming=false; origin=context.actor.position; context.actions.mode="item"; remaining=profile.duration; queue_redraw()
	return true
func cancel(reason := "") -> void:
	var interrupted:=busy()
	uid=""; input_source=""; aiming=false
	if interrupted and not reason.is_empty():
		last_reason=reason
		context.actions.report_action_feedback(reason)
	if context and context.actions and context.actions.mode in ["item","aim_item"]: context.actions.cancel("item_cancelled")
	queue_redraw()
func _input(event: InputEvent) -> void:
	if not aiming: return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		confirm(); context.actions.input_suppressed=.1; get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
		cancel(); context.actions.input_suppressed=.1; get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void: advance(delta)
func _interruption_reason() -> String:
	if not is_instance_valid(context.actor) or not context.region.available(generation): return "scope_left"
	if context.actor.get_node("HealthComponent").is_dead: return "dead"
	if "ui_blocked" in context.actor and context.actor.ui_blocked: return "interface"
	if context.actor.get_node("HealthComponent").hp<hp: return "受伤中断使用"
	if not context.actor.get_node("SkillManager").can_act(context.actor): return "控制状态中断使用"
	if context.items.locate(uid)!=context.id+".pocket": return "所选实物已离开口袋，使用中断"
	if profile.kind==ItemUseDefinition.Kind.COATING and str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))!=weapon_uid: return "主手武器已改变，涂附中断"
	if context.actions.operation_id!=operation_id: return "当前动作已改变，使用中断"
	if not aiming and context.actor.position.distance_to(origin)>12: return "移动中断使用"
	return ""
func advance(delta: float) -> void:
	if not busy(): return
	var reason:=_interruption_reason()
	if not reason.is_empty(): cancel(reason); return
	if not available(): cancel(); return
	if aiming:
		if aim_query.is_valid():
			var next:=Vector2(aim_query.call())
			if next.is_finite() and next.length_squared()>.01: direction=next.normalized()
		queue_redraw(); return
	remaining-=delta
	if remaining<=0: commit()
func commit() -> bool:
	if not busy(): return false
	var reason:=_interruption_reason()
	if not reason.is_empty(): cancel(reason); return false
	if not available(): cancel(); return false
	if profile.kind==ItemUseDefinition.Kind.BOOK and not _book_reason().is_empty(): cancel(_book_reason()); return false
	if context.actions.stamina.current<profile.stamina: cancel("体力不足，使用中断"); return false
	var plan:=CastPlan.new(); plan.requires_magic=false; plan.actor=context.actor; plan.action=SkillData.new(); plan.action.operation_id="item_use"; plan.stamina_cost=profile.stamina
	plan.instance_costs=[{"uid":uid,"property":"quantity","amount":1}]
	var supplies: CastingSupplies=context.actor.get_node("SkillManager").combinations.supplies
	var transaction:=CastTransaction.new(context.actor,supplies,CastTransaction.allocate_id())
	if not transaction.reserve(plan): transaction.rollback(); cancel("物品或资源已变化，使用中断"); return false
	if profile.kind==ItemUseDefinition.Kind.COATING:
		var weapon:=context.items.item(weapon_uid)
		if not weapon: transaction.rollback(); cancel("主手武器已改变，涂附中断"); return false
		var props:=weapon.properties.duplicate(true); props.coating={"id":profile.id,"expires_at":context.items.clock_seconds+profile.coating_seconds}
		context.items.set_properties(weapon_uid,props)
	elif profile.kind==ItemUseDefinition.Kind.CONSUMABLE:
		var buffs:=context.actor.get_node("BuffManager") as BuffManager
		for status in profile.payload.statuses: buffs.apply_buff(status,context.actor)
	elif profile.kind==ItemUseDefinition.Kind.BOOK:
		var learned: bool=context.fieldcraft.learn(context.id,profile.fieldcraft_skill) if not profile.fieldcraft_skill.is_empty() else context.martial.learn(profile.technique_id)
		if not learned: transaction.rollback(); cancel("知识条件已变化，阅读中断"); return false
	else:
		var projectile: ThrownDose=projectile_factory.call() if projectile_factory.is_valid() else ThrownDose.new()
		if not is_instance_valid(projectile): transaction.rollback(); cancel("投掷未能完成，物品未消费"); return false
		projectile.actor_context=context; projectile.profile=profile; projectile.direction=direction; projectile.remaining=profile.reach
		projectile.excluded=[context.actor.get_rid()]; context.region.root.add_child(projectile); projectile.global_position=context.actor.global_position
	transaction.commit()
	context.facts.publish("item_action_committed",context.id,{"item":profile.id,"weapon_uid":weapon_uid})
	cancel()
	if profile.kind==ItemUseDefinition.Kind.THROWABLE: context.actions.mode="recovery"; context.actions.remaining=.4
	return true
func _book_reason() -> String:
	if not profile.fieldcraft_skill.is_empty(): return context.fieldcraft.reason(context.id,profile.fieldcraft_skill) if context.fieldcraft else "野外技艺不可用"
	return context.martial.learn_reason(profile.technique_id)
func aim_endpoint() -> Vector2:
	var start:=context.actor.global_position
	var endpoint:=start+direction*profile.reach
	var hit:=ThrowTrajectory.first_hit(get_world_2d(),start,endpoint,[context.actor.get_rid()])
	return ThrowTrajectory.impact_point(hit,direction) if not hit.is_empty() else endpoint
func _draw() -> void:
	if not aiming or not context: return
	var endpoint:=aim_endpoint()-context.actor.global_position
	draw_dashed_line(Vector2.ZERO,endpoint,Color("d4c080"),2,12)
	draw_arc(endpoint,profile.splash_radius,0,TAU,32,Color("d4c080"),1)
