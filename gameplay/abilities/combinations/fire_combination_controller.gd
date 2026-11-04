class_name FireCombinationController
extends Node
## T1 personal preparation session. Existing spells keep their original execution path.

signal action_committed(result_id: String)
signal action_cancelled(reason: String)

const SIGIL := preload("res://gameplay/abilities/fields/fire_sigil.gd")
const RECIPE := preload("res://content/combinations/fire_sigil_fireball.tres")

var learned_recipes: Dictionary = {"fire_sigil_fireball": true} # Starter recipe for the current prototype.
var recipes: Array = []
var supplies := CastingSupplies.new()
var field: FireSigil # Compatibility alias for the most recently placed live field.
var fields: Array[FireSigil] = []
var allow_layered_fields := false
var pending: Dictionary = {}
var cooldowns: Dictionary = {}
var last_message := ""
var _message_remaining := 0.0
var _recovery := 0.0
var _serial := 0
var _committing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Load after script compilation; preloading every result creates a Resource/actor cycle.
	for id in preload("res://gameplay/abilities/combinations/recipe_catalog.gd").IDS:
		recipes.append(load("res://content/combinations/%s.tres" % id))

func handles(skill: SkillData) -> bool:
	return skill.get_id() in ["ignite", "fire_sigil", "frost_sigil", "storm_sigil", "pulse", "focus", "water_call", "oil_flask", "echo_mark", "venom_mist"]

func live_fields() -> Array[FireSigil]:
	var result: Array[FireSigil] = []
	for item in fields:
		if is_instance_valid(item) and not item.is_queued_for_deletion() and item.remaining > 0 and item.charges > 0:
			result.append(item)
	if is_instance_valid(field) and not field.is_queued_for_deletion() and field.remaining > 0 and field.charges > 0 and field not in result:
		result.append(field)
	return result

func _resolve_plan(skill: SkillData, actor: Node2D, empower: bool = false) -> Dictionary:
	var components: Array[Dictionary] = []
	if allow_layered_fields:
		components = CombinationResolver.resolve_components(skill, live_fields(), actor, recipes, learned_recipes, empower)
	else:
		components.append(CombinationResolver.resolve_recipes(skill, field if is_instance_valid(field) else null, actor, recipes, learned_recipes, empower))
	var result := components[0].duplicate()
	result.components = components
	result.cost = 0
	result.material_costs = {}
	result.cooldown_keys = {}
	result.cooldown = 0.0
	result.preparation = 0.0
	result.field_bonus = 0.0
	result.signature = []
	result.empower = empower
	result.status_conditions = []
	result.retained_boons = []
	result.consumed_boons = []
	var charged_boons: Dictionary = {}
	var names: Array[String] = []
	for i in range(components.size()):
		var component := components[i]
		var material := supplies.plan(skill, component.skill, i == 0)
		var boon := BoonSpellModifier.plan(material.skill, actor, empower)
		component.skill = boon.skill
		component.boon_conditions = boon.conditions
		var boon_cost := 0
		for condition in boon.conditions:
			result.status_conditions.append(condition)
			if condition.consume and not charged_boons.has(condition.id):
				boon_cost += int(condition.cost)
				charged_boons[condition.id] = true
		for title in boon.retained:
			if title not in result.retained_boons:
				result.retained_boons.append(title)
		for title in boon.spent:
			if title not in result.consumed_boons:
				result.consumed_boons.append(title)
		if not component.status_id.is_empty():
			result.status_conditions.append({"id": component.status_id, "version": component.status_version, "consume": component.consume_status, "cost": 0})
			if component.consume_status:
				var title: String = {"echo_ready": "回响印记", "resonant_guard": "共鸣护盾"}.get(component.status_id, component.status_id)
				if title not in result.consumed_boons:
					result.consumed_boons.append(title)
		component.cost = get_parent().effective_mana_cost(component.skill, actor, int(component.cost) + int(material.extra_mana) + boon_cost)
		component.material_costs = material.costs
		component.material_id = material.material_id
		component.field_bonus = material.field_bonus
		var key: String = component.recipe_id if not component.recipe_id.is_empty() else skill.get_id()
		result.cooldown_keys[key] = component.cooldown
		result.cost += component.cost
		result.cooldown = maxf(result.cooldown, component.cooldown)
		result.preparation = maxf(result.preparation, component.preparation)
		result.field_bonus = maxf(result.field_bonus, component.field_bonus)
		for id in material.costs:
			result.material_costs[id] = int(result.material_costs.get(id, 0)) + int(material.costs[id])
		var field_id: int = component.field.get_instance_id() if is_instance_valid(component.field) else 0
		result.signature.append([component.recipe_id, component.skill.get_id(), field_id, component.version, component.status_id, component.status_version, component.cost, material.material_id, material.costs.duplicate(), material.field_bonus, boon.conditions.duplicate(true)])
		names.append(component.skill.display_name)
	result.skill = components[0].skill
	result.material_id = components[0].material_id
	result.effect_label = " + ".join(names)
	return result

func boon_hint(plan: Dictionary) -> String:
	var text := ""
	if not plan.retained_boons.is_empty():
		text = "保留：" + "、".join(plan.retained_boons)
	if not plan.consumed_boons.is_empty():
		text += ("；" if not text.is_empty() else "") + "消耗：" + "、".join(plan.consumed_boons)
	return text

func remaining_cooldown(plan: Dictionary, action_id: String) -> float:
	var remaining := float(cooldowns.get(action_id, 0.0))
	for key in plan.cooldown_keys:
		remaining = maxf(remaining, float(cooldowns.get(key, 0.0)))
	return remaining

func preview(skill: SkillData, actor: Node2D, empower: bool = false) -> Dictionary:
	var result := _resolve_plan(skill, actor, empower)
	var key: String = result.recipe_id if not result.recipe_id.is_empty() else skill.get_id()
	result.cooldown_key = key
	result.reason = ""
	if not pending.is_empty() or _committing:
		result.reason = "正在准备"
	elif _recovery > 0.0:
		result.reason = "动作恢复中"
	elif remaining_cooldown(result, skill.get_id()) > 0:
		result.reason = "冷却中"
	var mana := actor.get_node_or_null("ManaComponent") as ManaComponent
	if mana and mana.mp < int(result.cost):
		result.reason = "法力不足，需要 %d MP" % result.cost
	if not supplies.can_pay(result.material_costs):
		result.reason = "施法材料不足：" + supplies.describe_cost(result.material_costs)
	result.ready = result.reason.is_empty()
	return result

func start(skill: SkillData, actor: Node2D, context: CastContext, source: String) -> bool:
	if get_tree().paused or _dead(actor) or ("ui_blocked" in actor and actor.ui_blocked):
		return false
	var plan := preview(skill, actor, context.empower)
	if not plan.ready:
		_message(plan.reason)
		return false
	var scope := _scope(actor)
	if not scope:
		return false
	if skill.get_id().ends_with("_sigil") and not _can_place(actor, actor.global_position):
		_message("铭刻位置被障碍物阻挡")
		return false
	_serial += 1
	plan.action = skill
	plan.source = source
	plan.actor = actor
	plan.scope = scope
	plan.position = actor.global_position
	plan.direction = context.direction
	plan.health = _health(actor)
	plan.execution_id = _serial
	plan.remaining = 0.8 if skill.get_id().ends_with("_sigil") else plan.preparation
	pending = plan
	_message("准备：%s" % plan.skill.display_name)
	return true

func cancel(reason: String = "动作已取消") -> void:
	if pending.is_empty():
		return
	pending = {}
	_recovery = 0.3
	_message(reason)
	action_cancelled.emit(reason)

func clear_field() -> void:
	for item in fields:
		if is_instance_valid(item):
			item.expire()
	if is_instance_valid(field) and field not in fields:
		field.expire()
	fields.clear()
	field = null

func clear_field_type(type: String) -> void:
	for i in range(fields.size() - 1, -1, -1):
		var item := fields[i]
		if not is_instance_valid(item):
			fields.remove_at(i)
		elif item.field_type == type:
			item.expire()
			fields.remove_at(i)
	var live := live_fields().filter(func(item: FireSigil): return item.field_type != type)
	field = live.back() if not live.is_empty() else null

func reset_session() -> void:
	cancel("休整")
	clear_field()
	cooldowns.clear()
	_recovery = 0.0
	last_message = ""

func _process(delta: float) -> void:
	for key in cooldowns:
		cooldowns[key] = maxf(0.0, cooldowns[key] - delta)
	_recovery = maxf(0.0, _recovery - delta)
	_message_remaining -= delta
	if _message_remaining <= 0:
		last_message = ""
	var owner_actor := get_parent().get_parent() as Node2D
	if owner_actor and _dead(owner_actor):
		clear_field()
	if pending.is_empty():
		return
	var actor: Node2D = pending.actor
	var inst: SkillInstance = get_parent().get_instance(pending.source)
	if not inst or inst.data != pending.action:
		cancel("装备已改变")
		return
	if not is_instance_valid(actor) or _dead(actor):
		cancel("死亡：准备取消")
		clear_field()
		return
	if not is_instance_valid(pending.scope) or pending.scope != _scope(actor):
		cancel("区域已改变")
		return
	if _health(actor) < pending.health:
		cancel("受到伤害：准备取消")
		return
	if "ui_blocked" in actor and actor.ui_blocked:
		cancel("操作已中断")
		return
	if pending.action.get_id().ends_with("_sigil") and actor.global_position.distance_to(pending.position) > 24:
		cancel("移动：铭刻取消")
		return
	pending.remaining -= delta
	if pending.remaining <= 0:
		_commit()

func _commit() -> void:
	var plan := pending
	var actor: Node2D = plan.actor
	var selected := _resolve_plan(plan.action, actor, plan.empower)
	if selected.signature != plan.signature:
		cancel("组合条件或素材已改变，未扣费")
		return
	var mana := actor.get_node_or_null("ManaComponent") as ManaComponent
	if mana and mana.mp < int(plan.cost):
		cancel("组合总法力不足，未扣费")
		return
	if not supplies.can_pay(plan.material_costs):
		cancel("组合材料已不足，未扣费")
		return
	var placement: bool = plan.action.get_id().ends_with("_sigil")
	if placement and not _can_place(actor, plan.position):
		cancel("铭刻位置被阻挡")
		return
	for component in plan.components:
		if not placement and not _can_execute(component.skill):
			cancel("组合效果不可用，未扣费")
			return
	_committing = true
	pending = {}
	var consumed_fields: Array[Dictionary] = []
	var snapshots: Dictionary = {}
	var buffs := actor.get_node_or_null("BuffManager") as BuffManager
	for component in plan.components:
		if component.field != null:
			if not component.field.consume(actor, component.version, plan.execution_id):
				_refund_conditions(consumed_fields, snapshots, buffs, plan.execution_id)
				_committing = false
				_message("法阵已改变，组合未释放")
				return
			consumed_fields.append(component)
	for condition in plan.status_conditions:
		if condition.consume and not snapshots.has(condition.id):
			snapshots[condition.id] = buffs.capture_status(condition.id)
			buffs.remove_status(condition.id)
	var paid_mana := mana != null and mana.use_mp(int(plan.cost))
	var paid_materials := (not mana or paid_mana) and supplies.pay(plan.material_costs)
	var batch := SkillExecutionBatch.new()
	var ok := paid_materials
	if ok and placement:
		var next := SIGIL.new()
		next.caster = actor
		next.field_type = plan.action.get_id().trim_suffix("_sigil")
		next.remaining += float(plan.field_bonus)
		if allow_layered_fields:
			clear_field_type(next.field_type)
		else:
			clear_field()
		plan.scope.add_child(next)
		next.global_position = plan.position
		fields.append(next)
		field = next
	elif ok:
		for component in plan.components:
			var context := CastContext.simple(actor, plan.direction, component.skill)
			context.world = plan.scope
			context.batch = batch
			context.family_id = "%s:%s" % [get_instance_id(), plan.execution_id]
			if component.field != null:
				context.target_position = component.field.global_position
				context.has_target_position = true
			if not get_parent().executor.execute(component.skill, context):
				ok = false
				break
		if ok:
			get_parent().executor.commit_batch(batch)
	if ok:
		cooldowns[plan.action.get_id()] = plan.action.cooldown
		for key in plan.cooldown_keys:
			cooldowns[key] = plan.cooldown_keys[key]
		_message("%s · %d MP%s" % [plan.effect_label, plan.cost, " · " + supplies.describe_cost(plan.material_costs) if not plan.material_costs.is_empty() else ""])
		for component in plan.components:
			get_parent().skill_used.emit(plan.source, component.skill)
	else:
		batch.abort()
		if paid_mana:
			mana.restore_mp(int(plan.cost))
		if paid_materials and not plan.material_costs.is_empty():
			supplies.grant(plan.material_costs)
		_refund_conditions(consumed_fields, snapshots, buffs, plan.execution_id)
		_message("组合未接受，资源与准备状态已恢复")
	_committing = false
	if ok:
		for component in plan.components:
			action_committed.emit(component.skill.get_id())
	else:
		action_cancelled.emit(last_message)

func _refund_conditions(consumed: Array[Dictionary], snapshots: Dictionary, buffs: BuffManager, execution_id: int) -> void:
	for component in consumed:
		if is_instance_valid(component.field):
			component.field.refund_consumption(execution_id)
	for id in snapshots:
		buffs.restore_status_snapshot(snapshots[id])

func _can_execute(skill: SkillData) -> bool:
	if skill.skill_type == SkillData.SkillType.BUFF:
		return skill.buff_resource != null and get_parent().get_parent().has_node("BuffManager")
	var paths := {"linear_projectile": "res://gameplay/abilities/archetypes/linear_projectile.tscn", "persistent_aoe": "res://gameplay/abilities/archetypes/persistent_aoe.tscn"}
	return paths.has(skill.archetype) and load(paths[skill.archetype]) is PackedScene

func _scope(actor: Node2D) -> Node:
	var scene := actor.get_tree().current_scene
	if not scene:
		return null
	if scene.has_method("get_active_region"):
		return scene.get_active_region()
	var run := scene.get_node_or_null("RunManager")
	if run and is_instance_valid(run._room_root):
		return run._room_root
	if GameRuntime.instance and GameRuntime.instance.get_region_runtime():
		var region: Node = GameRuntime.instance.get_region_runtime().get_current_region()
		if is_instance_valid(region):
			return region
	return scene

func _can_place(actor: Node2D, position: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96
	query.shape = circle
	query.transform = Transform2D(0, position)
	query.collision_mask = 1
	return actor.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _health(actor: Node2D) -> int:
	var health := actor.get_node_or_null("HealthComponent")
	return int(health.hp) if health else 1

func _dead(actor: Node2D) -> bool:
	var health := actor.get_node_or_null("HealthComponent")
	return bool(health.is_dead) if health else false

func _message(message: String) -> void:
	last_message = message
	_message_remaining = 2.5
