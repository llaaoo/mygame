class_name ConditionalCastController
extends Node
## T1 personal preparation session. Existing spells keep their original execution path.

signal action_committed(result_id: String)
signal action_cancelled(reason: String)
signal feedback_requested(message: String)

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
var _committing := false
var _manager: SkillManager
var _owner_actor: Node2D


func setup(manager: SkillManager, actor: Node2D) -> void:
	_manager = manager
	_owner_actor = actor


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
	var operation:=not skill.operation_id.is_empty()
	var primary := supplies.operation_plan(skill, _manager, null, false) if operation else {}
	var basis: SkillData=primary.skill if operation else skill
	if operation:
		basis=basis.create_runtime_variant()
		basis.id=skill.get_id()
	var medium:=primary.get("payload") as SpellPayloadData
	var source_fields:=SpellSourceResolver.fields_for(medium,live_fields(),actor)
	var explicit_source:=skill.operation_id in ["attune","extract"]
	var candidate_fields:=source_fields if explicit_source else live_fields()
	var components: Array[CastComponent] = []
	if not skill.conditional_cast or skill.operation_id=="extract":
		components.append(SpellCombinationResolver.base_plan(basis))
	elif allow_layered_fields:
		components = SpellCombinationResolver.resolve_components(basis, candidate_fields, actor, rules, learned_rules, empower, rule_index, supplies)
	else:
		components.append(SpellCombinationResolver.resolve_rules(basis, candidate_fields.back() if not candidate_fields.is_empty() else null, actor, rule_index.for_action(skill.get_id()), learned_rules, empower, true, supplies))
	if skill.operation_id=="extract" and not source_fields.is_empty():
		components[0].field=source_fields[0]
		components[0].version=source_fields[0].revision
	if skill.operation_id=="attune" and not source_fields.is_empty() and not components.any(func(component: CastComponent): return component.field!=null):
		components[0].field=source_fields[0]
		components[0].version=source_fields[0].revision
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
	result.action_cooldown = _manager.effective_cooldown(skill, actor, skill.cooldown)
	result.signature = [["action_cooldown", result.action_cooldown]]
	if operation:
		result.signature.append(["payload",medium.id if medium else "",supplies.prepared_uids.get(skill.get_id(),"")])
	if skill.operation_id=="extract" and basis.buff_resource:
		var buffs:=actor.get_node("BuffManager") as BuffManager
		result.signature.append(["energy",buffs.status_version(basis.buff_resource.status_id)])
	if explicit_source and medium:
		result.explanation.append(CastExplanationStep.new("source",medium.id,medium.title+"：只读取已存在的来源"))
	var stats := actor.get_node_or_null("StatsComponent") as StatsComponent
	if stats: result.signature.append(["attributes", stats.primary_values()])
	var survival: SurvivalService = actor.survival if "survival" in actor else null
	var fatigue_factor: float = survival.needs.preparation_multiplier() if survival else actor.actor_context.actions.needs.preparation_multiplier() if "actor_context" in actor and actor.actor_context and actor.actor_context.actions else 1.0
	result.signature.append(["fatigue", fatigue_factor])
	var equipment := actor.get_node_or_null("EquipmentManager") as EquipmentManager
	if equipment:
		result.signature.append(["equipment", equipment.loadout_revision])
		result.placement_radius = clampf(96 + equipment.casting_value("field_radius_bonus"), 48, 180)
		result.placement_duration = clampf(15 + equipment.casting_value("field_duration_bonus"), 5, 40)
	if basis.requires_soul_remnant:
		result.soul_remnant = SoulRemnant.nearest(actor, skill.soul_harvest_range + (equipment.casting_value("soul_range_bonus") if equipment else 0.0))
		result.soul_revision = result.soul_remnant.revision if result.soul_remnant else -1
		result.signature.append([result.soul_remnant.get_instance_id() if result.soul_remnant else 0, result.soul_revision, (actor.get_node("BuffManager") as BuffManager).status_version("soul_charge")])
	result.empower = empower
	result.explanation.append(CastExplanationStep.new("action", skill.get_id(), "基础动作：" + skill.display_name))
	result.status_conditions = []
	result.retained_boons = []
	result.consumed_boons = []
	var charged_boons: Dictionary = {}
	var names: Array[String] = []
	var infusion_fields: Array[FireSigil]=[]
	if not explicit_source: infusion_fields.assign(live_fields())
	# Active combinations have first claim; a field charge cannot fund two components.
	for component in components:
		if component.field != null:
			infusion_fields.erase(component.field)
	for i in range(components.size()):
		var component := components[i]
		if not component.rule_id.is_empty():
			var condition := FireSigil.title_for(component.field.field_type) + "，1次充能" if component.field else Buff.status_title(component.status_id)
			if not component.surface_state.is_empty():
				condition = "脚下" + SurfaceManager.surface_title(component.surface_state) + "：完成后消耗所在1格，保留周围介质"
			elif not component.substitute_material.is_empty():
				condition = supplies.title(component.substitute_material) + "×1替代地面（不附加投射物改造）"
			result.explanation.append(CastExplanationStep.new("combination", component.rule_id, condition + " → " + component.skill.display_name))
		var material := supplies.plan(skill, component.skill, i == 0, component.substitute_material, _manager)
		if not skill.operation_id.is_empty():
			result.operation_reason=str(material.get("reason",""))
			result.modifier_id=str(material.get("modifier_id",""))
			result.instance_costs.assign(material.get("instance_costs",[]))
			var payload:=material.get("payload") as SpellPayloadData
			if payload: result.explanation.append(CastExplanationStep.new("payload",payload.id,payload.title+"："+payload.describe()))
		elif not material.material_id.is_empty():
			var entry: CastingMaterialData = supplies.catalog[material.material_id]
			var purpose := "替代地面准备恩赐，不附加投射物改造；额外%d MP（修正前）" % entry.extra_mana if not component.substitute_material.is_empty() else entry.description
			result.explanation.append(CastExplanationStep.new("material", entry.id, entry.title + "：" + purpose))
		var boon := BoonSpellModifier.plan(material.skill, actor, empower)
		component.skill = boon.skill
		component.boon_conditions = boon.conditions
		var infusion_cost := MediumInfusion.plan(component, actor, infusion_fields, empower)
		if not component.infusion_label.is_empty():
			result.infusions.append(component.infusion_label)
			result.explanation.append(CastExplanationStep.new("equipment", "medium_infusion", component.infusion_label + "，额外%d MP（修正前），落点不变" % infusion_cost))
			infusion_fields.erase(component.field)
		var boon_cost := 0
		for condition in boon.conditions:
			result.status_conditions.append(condition)
			if not charged_boons.has("explain:" + condition.id):
				charged_boons["explain:" + condition.id] = true
				var snapshot := (actor.get_node("BuffManager") as BuffManager).capture_status(condition.id)
				var title: String = snapshot.buff.display_name if not snapshot.is_empty() else condition.id
				var mode := "保留" if not condition.consume else "部分消费，保留当前剩余时长50%" if condition.mode == CastStatusRequirement.ConsumptionMode.HALF_LIFETIME else "完整消费，失去持续收益"
				result.explanation.append(CastExplanationStep.new("boon", condition.id, "%s：%s；伤害倍率×%.2f，额外%d MP（修正前）；无伤害工具只获得形态变化" % [title, mode, condition.factor, condition.cost]))
			if condition.consume and not charged_boons.has(condition.id):
				boon_cost += int(condition.cost)
				charged_boons[condition.id] = true
		for title in boon.retained:
			if title not in result.retained_boons:
				result.retained_boons.append(title)
		for title in boon.spent:
			if title not in result.consumed_boons:
				result.consumed_boons.append(title)
		for title in boon.partial:
			if title not in result.partial_boons:
				result.partial_boons.append(title)
		if not component.status_id.is_empty():
			var requirement := CastStatusRequirement.new(component.status_id, component.status_version, component.consume_status)
			requirement.stacks = component.consume_stacks
			result.status_conditions.append(requirement)
			if component.consume_status:
				var title: String = {"echo_ready": "回响印记", "resonant_guard": "共鸣护盾", "soul_charge": "蕴魂1层"}.get(component.status_id, component.status_id)
				if title not in result.consumed_boons:
					result.consumed_boons.append(title)
		component.cost = _manager.effective_mana_cost(component.skill, actor, int(component.cost) + int(material.extra_mana) + boon_cost + infusion_cost)
		component.cooldown = _manager.effective_cooldown(component.skill, actor, component.cooldown)
		component.material_costs = material.costs
		component.material_id = material.material_id
		component.field_bonus = material.field_bonus
		var key: String = component.rule_id if not component.rule_id.is_empty() else skill.get_id()
		result.cooldown_keys[key] = component.cooldown
		result.cost += component.cost
		result.cooldown = maxf(result.cooldown, component.cooldown)
		result.preparation = maxf(result.preparation, component.preparation * fatigue_factor * (stats.preparation_multiplier if stats else 1.0) * clampf(1.0 + (equipment.casting_value("preparation_bonus") if equipment else 0.0), 0.5, 1.5))
		result.field_bonus = maxf(result.field_bonus, component.field_bonus)
		for id in material.costs:
			result.material_costs[id] = int(result.material_costs.get(id, 0)) + int(material.costs[id])
		result.signature.append(component.fingerprint())
		result.signature.append([result.modifier_id,result.instance_costs.duplicate(true)])
		names.append(component.skill.display_name + ("〔" + component.medium_label + "〕" if not component.medium_label.is_empty() else ""))
	result.skill = components[0].skill
	if explicit_source and medium and medium.source_kind=="field" and source_fields.is_empty(): result.operation_reason="所选法阵不在脚下或充能已耗尽；不会替换来源"
	result.field = components[0].field
	result.material_id = components[0].material_id
	result.effect_label = " + ".join(names)
	for component in components:
		var shape := ""
		if component.skill.skill_type == SkillData.SkillType.BUFF and component.skill.buff_resource:
			shape = "；" + component.skill.buff_resource.describe()
			if component.skill.buff_duration > 0: shape += "；本次持续%.1f秒" % component.skill.buff_duration
		var affinity := ElementCatalog.affinity_label(component.skill.tags)
		if "spray" in component.skill.tags:
			shape="，前方120、60°锥形；按住持续，松开即停"
		elif component.skill.skill_type == SkillData.SkillType.AOE:
			shape = "，半径%.0f" % (component.skill.aoe_visual.radius if component.skill.aoe_visual else component.skill.aoe_radius)
		elif component.skill.skill_type == SkillData.SkillType.PROJECTILE:
			shape = "，%d发、额外穿透%d" % [component.skill.projectile_count, component.skill.projectile_pierce]
		result.explanation.append(CastExplanationStep.new("effect", component.skill.get_id(), component.skill.display_name + ("〔" + affinity + "〕" if not affinity.is_empty() else "") + shape + ("；" + component.medium_label if not component.medium_label.is_empty() else "")))
	if fatigue_factor > 1:
		result.explanation.append(CastExplanationStep.new("survival", "fatigue", "疲劳：准备时间×%.2f，休整或醒神茶可缓解" % fatigue_factor))
	if stats and stats.preparation_multiplier < 1.0:
		result.explanation.append(CastExplanationStep.new("attributes", "agility", "敏捷%d：准备时间×%.2f，另与装备准备修正相乘" % [stats.effective_stat("agility"), stats.preparation_multiplier]))
	var material_label:=supplies.describe_cost(result.material_costs) if not result.material_costs.is_empty() else "无材料消耗"
	if not result.instance_costs.is_empty():
		material_label="每次脉冲消费所选瓶内1剂"
	result.explanation.append(CastExplanationStep.new("cost", "total", "总计%d MP；准备%.2f秒；%s" % [result.cost, result.preparation, material_label]))
	return result

func boon_hint(plan: CastPlan) -> String:
	var text := ""
	if not plan.retained_boons.is_empty():
		text = "保留：" + "、".join(plan.retained_boons)
	if not plan.consumed_boons.is_empty():
		text += ("；" if not text.is_empty() else "") + "完整消耗：" + "、".join(plan.consumed_boons)
	if not plan.partial_boons.is_empty():
		text += ("；" if not text.is_empty() else "") + "部分消耗：" + "、".join(plan.partial_boons) + "（保留剩余时长50%，较弱伤害强化）"
	if not plan.infusions.is_empty():
		text += ("；" if not text.is_empty() else "") + "借用：" + "、".join(plan.infusions) + "，额外法力已计入"
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
	if result.skill.requires_soul_remnant:
		var buffs := actor.get_node("BuffManager") as BuffManager
		if not result.soul_remnant:
			result.reason = "附近没有残魂：击败守卫后靠近残魂，再使用汲魂"
		elif buffs.get_stack_count("soul_charge") >= buffs.stack_limit(skill.buff_resource):
			result.reason = "蕴魂已满：先以Shift组合兑现，再汲取残魂"
	if skill.operation_id=="extract" and result.skill.buff_resource:
		var buffs:=actor.get_node("BuffManager") as BuffManager
		var capacity:=buffs.stack_limit(result.skill.buff_resource)
		if buffs.get_stack_count(result.skill.buff_resource.status_id)>=capacity: result.reason="同类蕴能已满（%d层），先手动兑现"%capacity
	if not supplies.can_pay_combat(result.material_costs):
		result.reason = "施法材料不足：" + supplies.describe_cost(result.material_costs)
	if not result.operation_reason.is_empty(): result.reason=result.operation_reason
	if not _manager.can_act(actor):
		result.reason = "麻痹中，无法施法"
	if skill.combination_only: result.reason = "组合结果须通过基础动作与现场条件触发"
	result.ready = result.reason.is_empty()
	return result

func start(skill: SkillData, actor: Node2D, context: CastContext, source: String) -> bool:
	if not skill or not context or not context.has_valid_target() or skill.combination_only or not _manager.knows_action(skill):
		return false
	if get_tree().paused or _dead(actor) or ("ui_blocked" in actor and actor.ui_blocked):
		return false
	var plan := preview(skill, actor, context.empower)
	if not plan.ready:
		_message(plan.reason)
		return false
	var scope := _scope(actor)
	if not scope:
		return false
	if not plan.skill.field_type.is_empty() and not _can_place(actor, actor.global_position, plan.placement_radius):
		_message("铭刻位置被障碍物阻挡")
		return false
	plan.requires_live_target=context.requires_live_target
	plan.live_target=context.target
	plan.action = skill
	plan.source = source
	plan.actor = actor
	plan.scope = scope
	plan.position = actor.global_position
	plan.direction = context.direction
	plan.has_target_position = skill.ground_targeted and context.has_target_position
	if plan.has_target_position:
		plan.target_position = CastContext.ground_point(actor, context.target_position, skill.cast_distance)
	plan.health = _health(actor)
	plan.execution_id = CastTransaction.allocate_id()
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
	if is_instance_valid(_owner_actor) and _dead(_owner_actor):
		clear_field()
	if pending.is_empty():
		return
	if pending.requires_live_target and not CastContext.target_available(pending.live_target):
		cancel("目标失效：准备取消")
		return
	var actor: Node2D = pending.actor
	var inst: SkillInstance = _manager.get_instance(pending.source)
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
	if not _manager.can_act(actor):
		cancel("受控：准备取消")
		return
	if _health(actor) < pending.health:
		cancel("受到伤害：准备取消")
		return
	if "ui_blocked" in actor and actor.ui_blocked:
		cancel("操作已中断")
		return
	if not pending.skill.field_type.is_empty() and actor.global_position.distance_to(pending.position) > 24:
		cancel("移动：铭刻取消")
		return
	pending.remaining -= delta
	if pending.remaining <= 0:
		_commit()

func _commit() -> void:
	var plan := pending
	var actor: Node2D = plan.actor
	var selected := build_plan(plan.action, actor, plan.empower)
	if selected.signature != plan.signature or not selected.operation_reason.is_empty():
		cancel("组合条件或素材已改变，未扣费")
		return
	var mana := actor.get_node_or_null("ManaComponent") as ManaComponent
	if mana and mana.mp < int(plan.cost):
		cancel("组合总法力不足，未扣费")
		return
	if not supplies.can_pay_combat(plan.material_costs):
		cancel("组合材料已不足，未扣费")
		return
	var placement: bool = not plan.skill.field_type.is_empty()
	if placement and not _can_place(actor, plan.position, plan.placement_radius):
		cancel("铭刻位置被阻挡")
		return
	for component in plan.components:
		if not placement and not _manager.executor.can_execute(component.skill, actor):
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
		next.field_type = plan.skill.field_type
		next.charges=plan.skill.field_charges
		next.radius = plan.placement_radius
		next.remaining = (clampf(plan.skill.field_duration+plan.placement_duration-15,5,40) if not plan.action.operation_id.is_empty() else plan.placement_duration) + float(plan.field_bonus)
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
			if plan.has_target_position:
				context.target_position = plan.target_position
				context.has_target_position = true
			if component.field != null and component.anchor_to_field:
				context.target_position = component.field.global_position
				context.has_target_position = true
			if not _manager.executor.execute(component.skill, context):
				ok = false
				break
		if ok:
			_manager.executor.commit_batch(batch, transaction.commit)
	if ok:
		var action_cooldown: float = plan.action_cooldown
		cooldowns[plan.action.get_id()] = action_cooldown
		cooldown_durations[plan.action.get_id()] = action_cooldown
		for key in plan.cooldown_keys:
			cooldowns[key] = plan.cooldown_keys[key]
			cooldown_durations[key] = plan.cooldown_keys[key]
		_message("%s · %d MP%s" % [plan.effect_label, plan.cost, " · " + supplies.describe_cost(plan.material_costs) if not plan.material_costs.is_empty() else ""])
		var exhausted: Array[String] = []
		for component in plan.components:
			if is_instance_valid(component.field) and component.field.charges == 0:
				var title := FireSigil.title_for(component.field.field_type)
				if title not in exhausted: exhausted.append(title)
		if not exhausted.is_empty():
			var next := build_plan(plan.action, actor, plan.empower)
			var notice := "、".join(exhausted) + "充能耗尽：" + plan.action.display_name + "下次为" + next.effect_label + " · " + effect_scope(next.skill)
			_message(last_message + "\n" + notice)
			feedback_requested.emit(notice)
		for component in plan.components:
			_manager.skill_used.emit(plan.source, component.skill)
	else:
		transaction.rollback()
		_message("组合未接受，资源与准备状态已恢复")
	_committing = false
	if ok:
		_manager.cast_committed.emit(plan)
		for component in plan.components:
			action_committed.emit(component.skill.get_id())
	else:
		action_cancelled.emit(last_message)

func _scope(actor: Node2D) -> Node:
	return CastContext.default_world(actor)

func _can_place(actor: Node2D, position: Vector2, radius: float = 96.0) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
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

func effect_scope(skill: SkillData) -> String:
	if not skill.field_type.is_empty(): return "脚下布阵"
	if "spray" in skill.tags: return "前方120、60°锥形 · 按住持续"
	match skill.skill_type:
		SkillData.SkillType.PROJECTILE: return "远程投射物"
		SkillData.SkillType.AOE:
			return ("落点半径" if skill.ground_targeted else "近身半径") + "%.0f" % (skill.aoe_visual.radius if skill.aoe_visual else skill.aoe_radius)
		SkillData.SkillType.BUFF: return "自身增益"
		SkillData.SkillType.DASH: return "位移"
	return "召唤"

func describe_plan(plan: CastPlan) -> String:
	var lines: Array[String] = []
	for step in plan.explanation:
		if step.kind != "effect": lines.append(step.text)
	for step in plan.explanation:
		if step.kind == "effect": lines.append("产生结果：" + step.text)
	var hint := boon_hint(plan)
	if not hint.is_empty(): lines.append(hint)
	lines.append("可准备" if plan.ready else plan.reason)
	return "\n".join(lines)

func describe_comparison(action: SkillData, actor: Node2D, normal: CastPlan = null, shifted: CastPlan = null, target: Node2D = null) -> String:
	if not normal: normal = preview(action, actor)
	if not shifted: shifted = preview(action, actor, true)
	var text := "普通施法\n" + describe_plan(normal) + "\n\nShift施法\n" + describe_plan(shifted)
	for rule: SpellCombinationRule in rule_index.for_action(action.get_id()):
		if not rule.required_surface.is_empty() and learned_rules.has(rule.id):
			var candidate := SpellCombinationResolver.resolve(action, null, actor, rule, true, true, supplies)
			text += "\n" + rule.result_skill.display_name + "准备条件：" + rule.condition_label() + ("（条件具备，优先处理法阵、回响与魂术）" if not candidate.rule_id.is_empty() else "（当前介质不满足）")
	if not is_instance_valid(target):
		return text + "\n\n目标反应在实际命中时判断；以上不保证命中或目标状态保持。"
	var target_buffs := target.get_node_or_null("BuffManager") as BuffManager
	var caster_buffs := actor.get_node_or_null("BuffManager") as BuffManager
	var candidates: Array[String] = []
	for component in shifted.components:
		for reaction in ElementReactionCatalog.for_skill(component.skill):
			if not reaction.required_target_status.is_empty() and (not target_buffs or not target_buffs.has_buff(reaction.required_target_status)): continue
			if not reaction.required_caster_status.is_empty() and (not caster_buffs or not caster_buffs.has_buff(reaction.required_caster_status)): continue
			if reaction.display_name not in candidates: candidates.append(reaction.display_name)
	return text + "\n\n若命中当前目标，可满足：" + ("、".join(candidates) if not candidates.is_empty() else "尚无额外反应条件") + "。实际命中时重新判断。"
