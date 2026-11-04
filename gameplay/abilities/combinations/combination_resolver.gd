class_name CombinationResolver
extends RefCounted

static func resolve(action: SkillData, field: Node2D, actor: Node2D, recipe: CombinationRecipe, learned: bool, empower: bool = false) -> Dictionary:
	var result := base_plan(action)
	if not learned or action.get_id() != recipe.trigger_action_id:
		return result
	if recipe.requires_empower and not empower:
		return result
	if not recipe.required_field_type.is_empty():
		if not is_instance_valid(field) or field.field_type != recipe.required_field_type or not field.is_available_to(actor):
			return result
	if not recipe.required_caster_status.is_empty():
		var buffs := actor.get_node_or_null("BuffManager") as BuffManager
		if not buffs or not buffs.has_buff(recipe.required_caster_status):
			return result
		result.status_id = recipe.required_caster_status
		result.status_version = buffs.status_version(recipe.required_caster_status)
		result.consume_status = recipe.consume_caster_status
	result.skill = recipe.result_skill
	result.recipe_id = recipe.id
	result.cost = recipe.mana_cost
	result.cooldown = recipe.cooldown
	result.rule_priority = recipe.priority
	if not recipe.required_field_type.is_empty():
		result.field = field
		result.version = field.revision
	return result

static func base_plan(action: SkillData) -> Dictionary:
	return {"skill": action, "recipe_id": "", "cost": action.mp_cost, "cooldown": action.cooldown, "field": null, "version": -1, "status_id": "", "status_version": -1, "consume_status": false, "preparation": 0.25}

static func resolve_recipes(action: SkillData, field: Node2D, actor: Node2D, recipes: Array, learned: Dictionary, empower: bool = false) -> Dictionary:
	var ordered := recipes.duplicate()
	ordered.sort_custom(func(a: CombinationRecipe, b: CombinationRecipe): return a.priority > b.priority if a.priority != b.priority else a.id < b.id)
	for recipe: CombinationRecipe in ordered:
		var result := resolve(action, field, actor, recipe, learned.has(recipe.id), empower)
		if not result.recipe_id.is_empty():
			result.preparation = recipe.preparation
			return result
	return base_plan(action)

static func resolve_components(action: SkillData, fields: Array, actor: Node2D, recipes: Array, learned: Dictionary, empower: bool = false) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var state_recipes := recipes.filter(func(recipe: CombinationRecipe): return recipe.required_field_type.is_empty())
	var field_recipes := recipes.filter(func(recipe: CombinationRecipe): return not recipe.required_field_type.is_empty())
	var state := resolve_recipes(action, null, actor, state_recipes, learned, empower)
	if not state.recipe_id.is_empty():
		candidates.append(state)
	for field in fields:
		var plan := resolve_recipes(action, field, actor, field_recipes, learned, empower)
		if not plan.recipe_id.is_empty():
			candidates.append(plan)
	var result: Array[Dictionary] = []
	# Mutually exclusive buffs choose highest priority, then the newest field.
	for candidate in candidates:
		var skill: SkillData = candidate.skill
		var group := skill.buff_resource.exclusive_group if skill.skill_type == SkillData.SkillType.BUFF and skill.buff_resource else ""
		var accepted := true
		if not group.is_empty():
			for previous in result.duplicate():
				var old_skill: SkillData = previous.skill
				if old_skill.skill_type == SkillData.SkillType.BUFF and old_skill.buff_resource and old_skill.buff_resource.exclusive_group == group:
					if int(previous.get("rule_priority", 0)) > int(candidate.get("rule_priority", 0)):
						accepted = false
					else:
						result.erase(previous)
		if accepted:
			result.append(candidate)
	if result.is_empty():
		result.append(base_plan(action))
	return result
