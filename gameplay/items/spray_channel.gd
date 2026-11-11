class_name SprayChannel
extends Node2D
var context: ActorContext
var held_query: Callable
var aim_query: Callable
var active := false
var source := ""
var uid := ""
var skill: SkillData
var payload_id := ""
var selection: Dictionary={}
var binding_revision := -1
var follows_global := false
var direction:=Vector2.RIGHT
var timer := 0.0
var hp := 0
var generation := 0
var operation_id := 0
var last_reason := ""
var empower := false
var modifier_id := ""
var _display_plan: CastPlan
func start(action: SkillData,binding: String,aim: Vector2,choice: Dictionary={},magic_empower := false) -> bool:
	return start_result(action,binding,aim,choice,magic_empower).accepted
func refusal_reason(action: SkillData,choice: Dictionary={},magic_empower := false) -> String:
	if get_tree().paused or not context.region.available(): return "当前无法喷洒"
	if context.actions.busy(): return "当前动作尚未结束"
	var manager:=context.actor.get_node("SkillManager") as SkillManager
	if not manager.knows_action(action): return "尚未学习喷洒动作"
	if manager.combinations.is_busy(): return "正在准备法术"
	if not manager.can_act(context.actor): return "控制状态中，无法喷洒"
	if context.actor.get_node("HealthComponent").is_dead or "ui_blocked" in context.actor and context.actor.ui_blocked: return "当前无法喷洒"
	var preview:=manager.combinations.preview(action,context.actor,magic_empower,choice)
	if not preview.ready: return preview.reason
	if preview.instance_costs.is_empty(): return "没有可用的喷剂，请选择口袋中的具体瓶"
	return ""
func start_result(action: SkillData,binding: String,aim: Vector2,choice: Dictionary={},magic_empower := false) -> OperationResult:
	last_reason=""
	if active:
		return OperationResult.success() if source==binding and selection==choice and empower==magic_empower else _refuse("已有喷洒正在进行")
	var reason:=refusal_reason(action,choice,magic_empower)
	if not reason.is_empty(): return _refuse(reason)
	var manager:=context.actor.get_node("SkillManager") as SkillManager
	var preview:=manager.combinations.preview(action,context.actor,magic_empower,choice)
	uid=preview.instance_costs[0].uid
	empower=magic_empower
	modifier_id=str(choice.get("modifier",manager.combinations.supplies.modifiers.get(action.get_id(),"")))
	_display_plan=preview
	skill=action; source=binding; selection=choice.duplicate(true); follows_global=choice.is_empty(); binding_revision=manager.shortcuts.revision(binding)
	payload_id=str(choice.get("payload",manager.combinations.supplies.selected.get(action.get_id(),"")))
	direction=aim.normalized() if aim.length_squared()>.01 else context.actions.facing
	timer=preview.preparation; hp=context.actor.get_node("HealthComponent").hp; generation=context.region.generation; operation_id=context.actions.operation_id
	active=true; context.actions.mode="spray"; context.actions.remaining=100000
	context.actions.guarding=false
	queue_redraw(); return OperationResult.success()
func _refuse(reason: String) -> OperationResult:
	last_reason=reason
	return OperationResult.reject(reason)
func stop(reason := "") -> void:
	var interrupted:=active
	active=false
	if interrupted and not reason.is_empty():
		last_reason=reason
		context.actions.report_action_feedback(reason)
	if context and is_instance_valid(context.actor) and not context.items.item(uid):
		var supplies: CastingSupplies=context.actor.get_node("SkillManager").combinations.supplies
		if supplies.prepared_uids.get(skill.get_id() if skill else "","")==uid and skill: supplies.prepared_uids.erase(skill.get_id())
	if context and context.actions.mode=="spray": context.actions.cancel("spray_stopped")
	queue_redraw()
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not active: return
	var actor:=context.actor
	if not is_instance_valid(actor) or not context.region.available(generation) or actor.get_node("HealthComponent").is_dead: stop(); return
	if "ui_blocked" in actor and actor.ui_blocked: stop(); return
	if actor.get_node("HealthComponent").hp<hp: stop("受伤中断喷洒"); return
	if not actor.get_node("SkillManager").can_act(actor): stop("控制状态中断喷洒"); return
	if context.actions.operation_id!=operation_id: stop("当前动作已改变，喷洒中断"); return
	if held_query.is_valid() and not held_query.call(source): stop(); return
	if aim_query.is_valid():
		var next:=Vector2(aim_query.call())
		if next.is_finite() and next.length_squared()>.01: direction=next.normalized()
	var manager:=actor.get_node("SkillManager") as SkillManager
	if manager.shortcuts.revision(source)!=binding_revision: stop("快捷绑定已改变，喷洒中断"); return
	var binding:=manager.shortcuts.binding(source)
	if binding.get("kind","")=="skill" and (manager.get_instance(source)==null or manager.get_instance(source).data!=skill): stop("快捷动作已改变，喷洒中断"); return
	if binding.get("kind","")=="item" and binding.get("uid","")!=uid: stop("所选喷剂已改变，喷洒中断"); return
	if follows_global and str(manager.combinations.supplies.selected.get(skill.get_id(),""))!=payload_id: stop("所选介质已改变，喷洒中断"); return
	if follows_global and str(manager.combinations.supplies.modifiers.get(skill.get_id(),""))!=modifier_id: stop("所选法术修饰已改变，喷洒中断"); return
	timer-=delta
	while timer<=.000001 and active:
		if not pulse(): stop(last_reason); return
		timer+=.5
	if active: _display_plan=manager.combinations.build_plan(skill,context.actor,empower,selection)
	queue_redraw()
func pulse() -> bool:
	if not active or not context.region.available(generation) or context.actions.operation_id!=operation_id: return false
	var manager:=context.actor.get_node("SkillManager") as SkillManager
	var bottle:=context.items.item(uid)
	if not bottle: last_reason="所选喷剂已失去，喷洒中断"; return false
	if int(bottle.properties.get("doses",0))<=0: last_reason="这瓶喷剂已用完"; return false
	if context.items.locate(uid)!=context.id+".pocket": last_reason="所选喷剂已离开口袋，喷洒中断"; return false
	if follows_global and str(manager.combinations.supplies.modifiers.get(skill.get_id(),""))!=modifier_id: last_reason="所选法术修饰已改变，喷洒中断"; return false
	var plan:=manager.combinations.build_plan(skill,context.actor,empower,selection)
	if not plan.operation_reason.is_empty(): last_reason=plan.operation_reason; return false
	if plan.instance_costs.is_empty() or plan.instance_costs[0].uid!=uid: last_reason="所选喷剂已改变，喷洒中断"; return false
	var mana:=context.actor.get_node("ManaComponent") as ManaComponent
	if not mana.cast_reason(plan.requires_magic).is_empty(): last_reason=mana.cast_reason(plan.requires_magic); return false
	if mana.mp<plan.cost: last_reason="法力不足，喷洒中断"; return false
	if not manager.executor.can_execute(plan.skill,context.actor): last_reason="当前效果无法释放，喷洒中断"; return false
	plan.actor=context.actor; plan.action=skill; plan.source=source
	var transaction:=CastTransaction.new(context.actor,manager.combinations.supplies,CastTransaction.allocate_id())
	if not transaction.reserve(plan): transaction.rollback(); last_reason="喷剂或资源已变化，喷洒中断"; return false
	transaction.commit()
	_display_plan=plan
	ConeCoverage.apply(context.actor,plan.skill,direction,"spray.%d"%CastTransaction.allocate_id(),plan.delivery_reach,plan.delivery_angle)
	if plan.requires_magic:
		manager.cast_committed.emit(plan); manager.skill_used.emit(source,plan.skill)
	context.facts.publish("spray_pulse",context.id,{"uid":uid})
	if not context.items.item(uid): stop("这瓶喷剂已用完")
	elif follows_global and str(manager.combinations.supplies.modifiers.get(skill.get_id(),""))!=modifier_id:
		# Legacy optional modifiers are single-use; never silently fall back to plain spray.
		stop()
	return true
func _draw() -> void:
	if not active: return
	if not _display_plan: return
	var reach:=_display_plan.delivery_reach
	var half_angle:=deg_to_rad(_display_plan.delivery_angle*.5)
	var polygon:=PackedVector2Array([Vector2.ZERO])
	var angle:=direction.angle()
	for i in range(17): polygon.append(Vector2.from_angle(angle-half_angle+2*half_angle*i/16)*reach)
	var tint:=Color(.6,.8,.6,.18)
	if context and context.items.item(uid):
		var data:=context.items.definitions.get(context.items.item(uid).definition_id) as ItemData
		if data and data.use_profile: tint=Color(data.use_profile.payload.color,.18)
	draw_colored_polygon(polygon,tint)
	draw_arc(Vector2.ZERO,reach,angle-half_angle,angle+half_angle,24,Color(tint, .7),2)
