class_name ExplorationContentValidator
extends RefCounted
## Read-only validation, shared by CLI and negative content tests.
var failures: Array[String] = []

func _fail(resource: Resource, message: String) -> void:
	failures.append("%s: %s" % [resource.resource_path if resource and not resource.resource_path.is_empty() else "<unsaved content>", message])

func validate(catalog: ExplorationContentCatalog) -> Array[String]:
	failures.clear()
	if not _validate_entries(catalog.chapter):
		return failures.duplicate()
	var supplies := CastingSupplies.new()
	var statuses: Dictionary = {}
	var tags: Dictionary = {}
	var fields: Dictionary = {"": true}
	for file in DirAccess.get_files_at("res://gameplay/abilities/data"):
		if not file.ends_with(".tres"):
			continue
		var resource := load("res://gameplay/abilities/data/" + file)
		var buff := resource as Buff
		var skill := resource as SkillData
		if skill:
			buff = skill.buff_resource
			for tag in skill.tags:
				tags[tag] = true
		if buff and not buff.status_id.is_empty():
			statuses[buff.status_id] = true
	for action in catalog.chapter.actions:
		if not action or action.get_id().is_empty() or action.combination_only:
			_fail(catalog.chapter, "Invalid equippable action")
			continue
		if not action.field_type.is_empty():
			fields[action.field_type] = true
		if not action.conditional_cast:
			_fail(action, "Exploration action must declare conditional_cast")
		if not action.required_material.is_empty() and (not supplies.catalog.has(action.required_material) or action.material_amount <= 0):
			_fail(action, "Invalid required material")
	if catalog.actions.size() != catalog.chapter.actions.size():
		_fail(catalog.chapter, "Duplicate action IDs")
	if catalog.regions.size() != catalog.chapter.regions.size():
		_fail(catalog.chapter, "Duplicate region IDs")
	if catalog.spell_rules.size() != catalog.chapter.spell_rules.size():
		_fail(catalog.chapter, "Duplicate spell combination rule IDs")
	for rule in catalog.chapter.spell_rules:
		if not rule or rule.id.is_empty() or not rule.result_skill or not rule.result_skill.combination_only:
			_fail(catalog.chapter, "Invalid spell combination rule")
			continue
		if not catalog.actions.has(rule.trigger_action_id) or rule.required_field_type not in fields or rule.mana_cost < 0 or rule.cooldown <= 0 or rule.preparation < 0:
			_fail(rule, "Invalid trigger, field or costs")
		if not rule.required_caster_status.is_empty() and not statuses.has(rule.required_caster_status):
			_fail(rule, "Unknown caster status: " + rule.required_caster_status)
		if rule.required_field_type.is_empty() and rule.required_caster_status.is_empty():
			_fail(rule, "Missing combination condition")
		if rule.consume_caster_status and rule.required_caster_status.is_empty():
			_fail(rule, "Missing consumed status")
		var boon := rule.result_skill.buff_resource
		if boon and boon.can_empower and (boon.status_id.is_empty() or boon.spell_tags.is_empty() or boon.empower_mana_cost < 0 or boon.spell_damage_multiplier <= 0 or boon.empower_damage_multiplier <= 0):
			_fail(rule, "Invalid spell boon")
	for material: CastingMaterialData in supplies.catalog.values():
		if material.extra_mana < 0 or material.damage_multiplier <= 0:
			_fail(material, "Invalid material cost/multiplier")
		for tag in material.added_tags:
			tags[tag] = true
	for recipe: CraftingRecipe in supplies.crafting_recipes.values():
		if recipe.inputs.is_empty() or recipe.output_count <= 0 or not supplies.catalog.has(recipe.output_id):
			_fail(recipe, "Invalid manufacturing output/inputs")
		_validate_materials(recipe, recipe.inputs, supplies)
	var claims: Dictionary = {}
	for region in catalog.chapter.regions:
		if not region or region.id.is_empty() or region.title.is_empty():
			_fail(catalog.chapter, "Invalid region")
			continue
		var layout := RunRoomGenerator.new().generate_room(region.seed, 0, region.room_type)
		region.reserve_interaction_space(layout)
		for point in region.interaction_points():
			if not layout.contains_offset(point.pos, 30):
				_fail(region, "Interaction outside arena")
			for obstacle in layout.obstacles:
				if Rect2(obstacle.position - obstacle.size * 0.5, obstacle.size).grow(40).has_point(point.pos):
					_fail(region, "Interaction blocked by geometry")
		for note in region.discoveries:
			_claim(claims, note.id, note)
			if note.title.is_empty() or note.text.is_empty():
				_fail(note, "Missing discovery title/text")
			for action in note.actions:
				if not catalog.actions.has(action):
					_fail(note, "Unknown action grant: " + action)
			for rule_id in note.spell_rules:
				if not catalog.spell_rules.has(rule_id):
					_fail(note, "Unknown spell combination grant: " + rule_id)
			_validate_materials(note, note.materials, supplies)
		for encounter in region.encounters:
			if encounter.hp <= 0 or encounter.speed <= 0 or encounter.role not in [0, 1, 2]:
				_fail(encounter, "Invalid encounter")
		for event in region.events:
			_claim(claims, event.id, event)
			if event.choices.size() < 2:
				_fail(event, "World event requires choices")
			var choices: Dictionary = {}
			for choice in event.choices:
				if choice.id.is_empty() or choices.has(choice.id) or choice.text.is_empty():
					_fail(choice, "Invalid/duplicate world choice")
				choices[choice.id] = true
		for puzzle in region.spell_objects:
			_claim(claims, puzzle.id, puzzle)
			if puzzle.routes.is_empty():
				_fail(puzzle, "Missing spell puzzle route")
			for route in puzzle.routes:
				if route.steps.is_empty():
					_fail(puzzle, "Empty spell puzzle route")
				for step in route.steps:
					if not tags.has(step):
						_fail(puzzle, "Unknown spell tag: " + step)
			_validate_materials(puzzle, puzzle.materials, supplies)
		for exit in region.exits:
			if not catalog.regions.has(exit.target) or (not exit.required_action.is_empty() and not catalog.actions.has(exit.required_action)):
				_fail(region, "Dangling exit/knowledge requirement")
	var quest_ids: Dictionary = {}
	for quest in catalog.chapter.quests:
		if quest_ids.has(quest.id):
			_fail(quest, "Duplicate quest ID")
		quest_ids[quest.id] = true
		if quest.attribute_points <= 0 or quest.id.is_empty() or quest.required_claims.is_empty():
			_fail(quest, "Invalid quest reward/objectives")
		for id in quest.required_claims:
			if not claims.has(id):
				_fail(quest, "Missing quest discovery: " + id)
		for id in quest.required_clears:
			if not catalog.regions.has(id):
				_fail(quest, "Missing quest region: " + id)
	for id in catalog.regions:
		var visited: Dictionary = {}
		var queue: Array = [id]
		while not queue.is_empty():
			var current: String = queue.pop_front()
			if visited.has(current) or not catalog.regions.has(current):
				continue
			visited[current] = true
			for exit in catalog.regions[current].exits:
				queue.append(exit.target)
		if visited.size() != catalog.regions.size() or not visited.has("camp"):
			_fail(catalog.regions[id], "Region cannot reach camp/remaining regions")
	return failures.duplicate()

func _claim(claims: Dictionary, id: String, resource: Resource) -> void:
	if id.is_empty() or claims.has(id):
		_fail(resource, "Missing/duplicate stable discovery ID: " + id)
	claims[id] = true

func _validate_materials(resource: Resource, values: Dictionary, supplies: CastingSupplies) -> void:
	for id in values:
		if not supplies.catalog.has(id) and not CastingSupplies.RAW_TITLES.has(id):
			_fail(resource, "Unknown material: " + str(id))
		if not values[id] is int or int(values[id]) <= 0:
			_fail(resource, "Material quantities must be positive integers")

func _validate_entries(chapter: ExplorationChapterData) -> bool:
	var resources: Array = []
	resources.append_array(chapter.actions)
	resources.append_array(chapter.spell_rules)
	resources.append_array(chapter.quests)
	for region in chapter.regions:
		resources.append(region)
		if region:
			resources.append_array(region.encounters)
			resources.append_array(region.interaction_points())
			for event in region.events:
				if event:
					resources.append_array(event.choices)
			for puzzle in region.spell_objects:
				if puzzle:
					resources.append_array(puzzle.routes)
	if null in resources:
		_fail(chapter, "Missing content resource reference")
		return false
	return true
