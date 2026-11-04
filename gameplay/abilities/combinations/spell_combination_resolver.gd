class_name SpellCombinationResolver
extends RefCounted

static func resolve(action: SkillData, field: Node2D, actor: Node2D, rule: SpellCombinationRule, learned: bool, empower: bool = false) -> CastComponent:
	var result := base_plan(action)
	if not learned or action.get_id() != rule.trigger_action_id:
		return result
	if rule.requires_empower and not empower:
		return result
	if not rule.required_field_type.is_empty():
		if not is_instance_valid(field) or field.field_type != rule.required_field_type or not field.is_available_to(actor):
			return result
	if not rule.required_caster_status.is_empty():
		var buffs := actor.get_node_or_null("BuffManager") as BuffManager
		if not buffs or not buffs.has_buff(rule.required_caster_status):
			return result
		result.status_id = rule.required_caster_status
		result.status_version = buffs.status_version(rule.required_caster_status)
		result.consume_status = rule.consume_caster_status
	result.skill = rule.result_skill
	result.rule_id = rule.id
	result.cost = rule.mana_cost
	result.cooldown = rule.cooldown
	result.rule_priority = rule.priority
	if not rule.required_field_type.is_empty():
		result.field = field
		result.version = field.revision
	return result

static func base_plan(action: SkillData) -> CastComponent:
	var result := CastComponent.new()
	result.skill = action
	result.cost = action.mp_cost
	result.cooldown = action.cooldown
	result.preparation = action.preparation
	return result

static func resolve_rules(action: SkillData, field: Node2D, actor: Node2D, rules: Array, learned: Dictionary, empower: bool = false, presorted: bool = false) -> CastComponent:
	var ordered := rules if presorted else rules.duplicate()
	if not presorted:
		ordered.sort_custom(func(a: SpellCombinationRule, b: SpellCombinationRule): return a.priority > b.priority if a.priority != b.priority else a.id < b.id)
	for rule: SpellCombinationRule in ordered:
		var result := resolve(action, field, actor, rule, learned.has(rule.id), empower)
		if not result.rule_id.is_empty():
			result.preparation = rule.preparation
			return result
	return base_plan(action)

static func resolve_components(action: SkillData, fields: Array, actor: Node2D, rules: Array, learned: Dictionary, empower: bool = false, index: SpellRuleIndex = null) -> Array[CastComponent]:
	var candidates: Array[CastComponent] = []
	var state_rules: Array = index.for_action(action.get_id(), "state") if index else rules.filter(func(rule: SpellCombinationRule): return rule.required_field_type.is_empty())
	var field_rules: Array = index.for_action(action.get_id(), "field") if index else rules.filter(func(rule: SpellCombinationRule): return not rule.required_field_type.is_empty())
	var state := resolve_rules(action, null, actor, state_rules, learned, empower, index != null)
	if not state.rule_id.is_empty():
		candidates.append(state)
	for field in fields:
		var plan := resolve_rules(action, field, actor, field_rules, learned, empower, index != null)
		if not plan.rule_id.is_empty():
			candidates.append(plan)
	var result: Array[CastComponent] = []
	# Mutually exclusive buffs choose highest priority, then the newest field.
	for candidate in candidates:
		var skill: SkillData = candidate.skill
		var group := skill.buff_resource.exclusive_group if skill.skill_type == SkillData.SkillType.BUFF and skill.buff_resource else ""
		var accepted := true
		if not group.is_empty():
			for previous in result.duplicate():
				var old_skill: SkillData = previous.skill
				if old_skill.skill_type == SkillData.SkillType.BUFF and old_skill.buff_resource and old_skill.buff_resource.exclusive_group == group:
					if previous.rule_priority > candidate.rule_priority:
						accepted = false
					else:
						result.erase(previous)
		if accepted:
			result.append(candidate)
	if result.is_empty():
		result.append(base_plan(action))
	return result
