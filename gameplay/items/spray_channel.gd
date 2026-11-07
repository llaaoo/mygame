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
var direction:=Vector2.RIGHT
var timer := 0.0
var hp := 0
var generation := 0
var operation_id := 0
func start(action: SkillData,binding: String,aim: Vector2) -> bool:
	if active: return true
	if get_tree().paused or context.actions.busy() or not context.region.available(): return false
	var manager:=context.actor.get_node("SkillManager") as SkillManager
	if manager.combinations.is_busy() or not manager.can_act(context.actor) or context.actor.get_node("HealthComponent").is_dead or "ui_blocked" in context.actor and context.actor.ui_blocked: return false
	var preview:=manager.combinations.preview(action,context.actor)
	if not preview.ready or preview.instance_costs.is_empty(): return false
	uid=preview.instance_costs[0].uid
	skill=action; source=binding; payload_id=str(manager.combinations.supplies.selected.get(action.get_id(),""))
	direction=aim.normalized() if aim.length_squared()>.01 else context.actions.facing
	timer=.25; hp=context.actor.get_node("HealthComponent").hp; generation=context.region.generation; operation_id=context.actions.operation_id
	active=true; context.actions.mode="spray"; context.actions.remaining=100000
	context.actions.guarding=false
	queue_redraw(); return true
func stop() -> void:
	active=false
	if context and is_instance_valid(context.actor) and not context.items.item(uid):
		var supplies: CastingSupplies=context.actor.get_node("SkillManager").combinations.supplies
		if supplies.prepared_uids.get(skill.get_id() if skill else "","")==uid and skill: supplies.prepared_uids.erase(skill.get_id())
	if context and context.actions.mode=="spray": context.actions.cancel("spray_stopped")
	queue_redraw()
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if not active: return
	var actor:=context.actor
	if not is_instance_valid(actor) or not context.region.available(generation) or context.actions.operation_id!=operation_id or actor.get_node("HealthComponent").is_dead or actor.get_node("HealthComponent").hp<hp or not actor.get_node("SkillManager").can_act(actor) or "ui_blocked" in actor and actor.ui_blocked: stop(); return
	if held_query.is_valid() and not held_query.call(source): stop(); return
	if aim_query.is_valid():
		var next:=Vector2(aim_query.call())
		if next.is_finite() and next.length_squared()>.01: direction=next.normalized()
	var manager:=actor.get_node("SkillManager") as SkillManager
	if manager.get_instance(source)==null or manager.get_instance(source).data!=skill or str(manager.combinations.supplies.selected.get(skill.get_id(),""))!=payload_id: stop(); return
	timer-=delta
	while timer<=.000001 and active:
		if not pulse(): stop(); return
		timer+=.5
	queue_redraw()
func pulse() -> bool:
	if not active or not context.region.available(generation) or context.actions.operation_id!=operation_id: return false
	var manager:=context.actor.get_node("SkillManager") as SkillManager
	var plan:=manager.combinations.build_plan(skill,context.actor)
	if not plan.operation_reason.is_empty() or plan.instance_costs.is_empty() or plan.instance_costs[0].uid!=uid or not manager.executor.can_execute(plan.skill,context.actor): return false
	plan.actor=context.actor; plan.action=skill; plan.source=source
	var transaction:=CastTransaction.new(context.actor,manager.combinations.supplies,CastTransaction.allocate_id())
	if not transaction.reserve(plan): transaction.rollback(); return false
	transaction.commit()
	ConeCoverage.apply(context.actor,plan.skill,direction,"spray.%d"%CastTransaction.allocate_id())
	manager.cast_committed.emit(plan); manager.skill_used.emit(source,plan.skill)
	context.facts.publish("spray_pulse",context.id,{"uid":uid})
	if not context.items.item(uid): stop()
	return true
func _draw() -> void:
	if not active: return
	var polygon:=PackedVector2Array([Vector2.ZERO])
	var angle:=direction.angle()
	for i in range(17): polygon.append(Vector2.from_angle(angle-deg_to_rad(30)+deg_to_rad(60)*i/16)*120)
	var tint:=Color(.6,.8,.6,.18)
	if context and context.items.item(uid):
		var data:=context.items.definitions.get(context.items.item(uid).definition_id) as ItemData
		if data and data.use_profile: tint=Color(data.use_profile.payload.color,.18)
	draw_colored_polygon(polygon,tint)
	draw_arc(Vector2.ZERO,120,angle-deg_to_rad(30),angle+deg_to_rad(30),24,Color(tint, .7),2)
