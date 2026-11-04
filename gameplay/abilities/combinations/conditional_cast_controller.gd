class_name ConditionalCastController
extends Node
## T1 personal preparation session. Existing spells keep their original execution path.

signal action_committed(result_id: String)
signal action_cancelled(reason: String)

const SIGIL := preload("res://gameplay/abilities/fields/fire_sigil.gd")
const STARTER_RULE := preload("res://content/combinations/fire_sigil_fireball.tres")

var learned_rules: Dictionary = {"fire_sigil_fireball": true} # Starter rule for the current prototype.
var rules: Array[SpellCombinationRule] = []
var rule_index := SpellRuleIndex.new()
var supplies := CastingSupplies.new()
var field: FireSigil # Compatibility alias for the most recently placed live field.
var fields: Array[FireSigil] = []
var allow_layered_fields := false
var pending := CastPlan.new()
var cooldowns: Dictionary = {}
var cooldown_durations: Dictionary = {}
var last_message := ""
var _message_remaining := 0.0
var _recovery := 0.0
var _serial := 0
var _committing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	RuntimeRegistration.register_ticker(self)
	# Load after script compilation; preloading every result creates a Resource/actor cycle.
	var chapter := load("res://content/exploration/chapter.tres") as ExplorationChapterData
	rules.assign(chapter.spell_rules)
	rule_index.rebuild(rules)

func is_busy() -> bool:
	return _committing or not pending.is_empty()

func handles(skill: SkillData) -> bool:
	return skill.conditional_cast

func live_fields() -> Array[FireSigil]:
	var result: Array[FireSigil] = []
	for item in fields:
		if is_instance_valid(item) and not item.is_queued_for_deletion() and item.remaining > 0 and item.charges > 0:
			result.append(item)
	if is_instance_valid(field) and not field.is_queued_for_deletion() and field.remaining > 0 and field.charges > 0 and field not in result:
		result.append(field)
	return result

func build_plan(skill: SkillData, actor: Node2D, empower: bool = false) -> CastPlan:
	var components: Array[CastComponent] = []
	if not skill.conditional_cast:
		components.append(SpellCombinationResolver.base_plan(skill))
	elif allow_layered_fields:
		components = SpellCombinationResolver.resolve_components(skill, live_fields(), actor, rules, learned_rules, empower, rule_index)
	else:
		components.append(SpellCombinationResolver.resolve_rules(skill, field if is_instance_valid(field) else null, actor, rule_index.for_action(skill.get_id()), learned_rules, empower, true))
	var result := CastPlan.new()
	result.rule_id = components[0].rule_id
	result.field = components[0].field
	result.components = components
	result.cost = 0
	result.material_costs = {}
	result.cooldown_keys = {}
	result.cooldown = 0.0
	result.preparation = 0.0
	result.field_bonus = 0.0
	result.action_cooldown = get_parent().effective_cooldown(skill, actor, skill.cooldown)
	result.signature = [["action_cooldown", result.action_cooldown]]
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
			result.status_conditions.append(CastStatusRequirement.new(component.status_id, component.status_version, component.consume_status))
			if component.consume_status:
				var title: String = {"echo_ready": "回响印记", "resonant_guard": "共鸣护盾"}.get(component.status_id, component.status_id)
				if title not in result.consumed_boons:
					result.consumed_boons.append(title)
		component.cost = get_parent().effective_mana_cost(component.skill, actor, int(component.cost) + int(material.extra_mana) + boon_cost)
		component.cooldown = get_parent().effective_cooldown(component.skill, actor, component.cooldown)
		component.material_costs = material.costs
		component.material_id = material.material_id
		component.field_bonus = material.field_bonus
		var key: String = component.rule_id if not component.rule_id.is_empty() else skill.get_id()
		result.cooldown_keys[key] = component.cooldown
		result.cost += component.cost
		result.cooldown = maxf(result.cooldown, component.cooldown)
		result.preparation = maxf(result.preparation, component.preparation)
		result.field_bonus = maxf(result.field_bonus, component.field_bonus)
		for id in material.costs:
			result.material_costs[id] = int(result.material_costs.get(id, 0)) + int(material.costs[id])
		result.signature.append(component.fingerprint())
		names.append(component.skill.display_name)
	result.skill = components[0].skill
	result.material_id = components[0].material_id
	result.effect_label = " + ".join(names)
	return result

func boon_hint(plan: CastPlan) -> String:
	var text := ""
	if not plan.retained_boons.is_empty():
		text = "保留：" + "、".join(plan.retained_boons)
	if not plan.consumed_boons.is_empty():
		text += ("；" if not text.is_empty() else "") + "消耗：" + "、".join(plan.consumed_boons)
	return text

func cooldown_state(plan: CastPlan, action_id: String) -> Dictionary:
	var remaining := 0.0
	var duration := float(plan.cooldown)
	var keys: Array = plan.cooldown_keys.keys()
	if action_id not in keys:
		keys.append(action_id)
	for key in keys:
		var value := float(cooldowns.get(key, 0.0))
		if value > remaining:
			remaining = value
			duration = float(cooldown_durations.get(key, maxf(value, duration)))
	return {"remaining": remaining, "duration": duration}

func remaining_cooldown(plan: CastPlan, action_id: String) -> float:
	return cooldown_state(plan, action_id).remaining

func preview(skill: SkillData, actor: Node2D, empower: bool = false) -> CastPlan:
	var result := build_plan(skill, actor, empower)
	var key: String = result.rule_id if not result.rule_id.is_empty() else skill.get_id()
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
	if not skill.field_type.is_empty() and not _can_place(actor, actor.global_position):
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
	plan.remaining = plan.preparation
	pending = plan
	_message("准备：%s" % plan.skill.display_name)
	return true

func cancel(reason: String = "动作已取消") -> void:
	if pending.is_empty():
		return
	pending = CastPlan.new()
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
	cooldown_durations.clear()
	_recovery = 0.0
	last_message = ""

func tick(delta: float) -> void:
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
	if not pending.action.field_type.is_empty() and actor.global_position.distance_to(pending.position) > 24:
		cancel("移动：铭刻取消")
		return
	pending.remaining -= delta
	if pending.remaining <= 0:
		_commit()

func _commit() -> void:
	var plan := pending
	var actor: Node2D = plan.actor
	var selected := build_plan(plan.action, actor, plan.empower)
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
	var placement: bool = not plan.action.field_type.is_empty()
	if placement and not _can_place(actor, plan.position):
		cancel("铭刻位置被阻挡")
		return
	for component in plan.components:
		if not placement and not _can_execute(component.skill):
			cancel("组合效果不可用，未扣费")
			return
	_committing = true
	pending = CastPlan.new()
	var transaction := CastTransaction.new(actor, supplies, plan.execution_id)
	var batch := transaction.batch
	var ok := transaction.reserve(plan)
	if ok and placement:
		var next := SIGIL.new()
		next.caster = actor
		next.field_type = plan.action.field_type
		next.remaining += float(plan.field_bonus)
		if allow_layered_fields:
			clear_field_type(next.field_type)
		else:
			clear_field()
		plan.scope.add_child(next)
		next.global_position = plan.position
		fields.append(next)
		field = next
		transaction.commit()
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
			get_parent().executor.commit_batch(batch, transaction.commit)
	if ok:
		var action_cooldown: float = plan.action_cooldown
		cooldowns[plan.action.get_id()] = action_cooldown
		cooldown_durations[plan.action.get_id()] = action_cooldown
		for key in plan.cooldown_keys:
			cooldowns[key] = plan.cooldown_keys[key]
			cooldown_durations[key] = plan.cooldown_keys[key]
		_message("%s · %d MP%s" % [plan.effect_label, plan.cost, " · " + supplies.describe_cost(plan.material_costs) if not plan.material_costs.is_empty() else ""])
		for component in plan.components:
			get_parent().skill_used.emit(plan.source, component.skill)
	else:
		transaction.rollback()
		_message("组合未接受，资源与准备状态已恢复")
	_committing = false
	if ok:
		for component in plan.components:
			action_committed.emit(component.skill.get_id())
	else:
		action_cancelled.emit(last_message)

func _can_execute(skill: SkillData) -> bool:
	return get_parent().executor.can_execute(skill, get_parent().get_parent())

func _scope(actor: Node2D) -> Node:
	return CastContext.default_world(actor)

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
