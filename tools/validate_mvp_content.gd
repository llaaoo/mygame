extends SceneTree
## Validate authored content and route connectivity without changing game state.

func _init() -> void:
	var failures: Array[String] = []
	var regions: Dictionary = {}
	var claims: Dictionary = {}
	var recipes: Dictionary = {}
	var supplies := CastingSupplies.new()
	for path in preload("res://gameplay/abilities/combinations/recipe_catalog.gd").IDS:
		var recipe := load("res://content/combinations/%s.tres" % path) as CombinationRecipe
		if not recipe or recipe.id != path or not recipe.result_skill or not recipe.result_skill.combination_only:
			failures.append("Invalid recipe: " + path)
			continue
		if recipe.mana_cost < 0 or recipe.cooldown <= 0 or recipe.required_field_type not in ["", "fire", "frost", "storm"] or (recipe.required_field_type.is_empty() and recipe.required_caster_status.is_empty()):
			failures.append("Invalid recipe parameters: " + path)
		if recipe.consume_caster_status and recipe.required_caster_status.is_empty():
			failures.append("Missing consumed status: " + path)
		recipes[path] = recipe
		var boon: Buff = recipe.result_skill.buff_resource
		if boon and boon.can_empower:
			if boon.status_id.is_empty() or boon.spell_tags.is_empty() or boon.empower_mana_cost < 0 or boon.spell_damage_multiplier <= 0 or boon.empower_damage_multiplier <= 0:
				failures.append("Invalid spell boon: " + path)
	for id in MVPGame.REGIONS:
		var region := load("res://content/exploration/%s.tres" % id) as ExplorationRegionData
		if not region or region.id != id or region.title.is_empty():
			failures.append("Invalid region: " + id)
			continue
		regions[id] = region
		var layout := RunRoomGenerator.new().generate_room(region.seed, 0, region.room_type)
		region.reserve_interaction_space(layout)
		for point in region.discoveries + region.events + region.exits + region.spell_objects:
			if not layout.contains_offset(point.pos, 30):
				failures.append("Interaction outside arena in " + id)
			for obstacle in layout.obstacles:
				if Rect2(obstacle.position - obstacle.size * 0.5, obstacle.size).grow(40).has_point(point.pos):
					failures.append("Interaction blocked by geometry in " + id)
		for note in region.discoveries:
			if not note.has("id") or claims.has(note.id) or not note.has("pos") or not note.has("text"):
				failures.append("Duplicate or invalid discovery in " + id)
				continue
			claims[note.id] = true
			for action in note.get("actions", []):
				var skill := load("res://gameplay/abilities/data/%s_data.tres" % action) as SkillData
				if not skill or skill.combination_only:
					failures.append("Invalid equippable grant: " + str(action))
				elif not skill.required_material.is_empty() and not supplies.catalog.has(skill.required_material):
					failures.append("Unknown required material: " + str(action))
			for recipe_id in note.get("recipes", []):
				if not recipes.has(recipe_id):
					failures.append("Unknown recipe grant: " + str(recipe_id))
		for encounter in region.encounters:
			if int(encounter.get("hp", 0)) <= 0 or not encounter.has("pos"):
				failures.append("Invalid encounter in " + id)
		for event in region.events:
			if claims.has(event.id) or event.get("choices", []).size() < 2:
				failures.append("Invalid world event in " + id)
			claims[event.id] = true
			var options: Dictionary = {}
			for option in event.choices:
				if options.has(option.id) or option.get("text", "").is_empty():
					failures.append("Invalid world choice in " + id)
				options[option.id] = true
		for object in region.spell_objects:
			if claims.has(object.id) or object.get("routes", []).is_empty():
				failures.append("Invalid spell object: " + str(object.id))
			claims[object.id] = true
			for route in object.routes:
				if route.is_empty():
					failures.append("Empty spell puzzle route in " + id)
		for grant in region.discoveries + region.spell_objects:
			for material_id in grant.get("materials", {}):
				if not supplies.catalog.has(material_id) and not CastingSupplies.RAW_TITLES.has(material_id):
					failures.append("Unknown material grant: " + str(material_id))
				if int(grant.materials[material_id]) <= 0:
					failures.append("Invalid material quantity in " + id)
	for material_id in supplies.catalog:
		var material: CastingMaterialData = supplies.catalog[material_id]
		if not material or material.id != material_id or material.extra_mana < 0:
			failures.append("Invalid casting material: " + str(material_id))
	for id in MVPGame.QUEST_IDS:
		var quest := load("res://content/exploration/quests/%s.tres" % id) as ExplorationQuestData
		if not quest or quest.id != id or quest.attribute_points <= 0 or quest.required_claims.is_empty():
			failures.append("Invalid quest: " + id)
			continue
		for claim_id in quest.required_claims:
			if not claims.has(claim_id):
				failures.append("Missing quest discovery: " + claim_id)
		for region_id in quest.required_clears:
			if not regions.has(region_id):
				failures.append("Missing quest region: " + region_id)
	for id in regions:
		for exit in regions[id].exits:
			if not regions.has(exit.get("target", "")) or not exit.has("pos"):
				failures.append("Dangling exit in " + str(id))
		var visited: Dictionary = {}
		var queue: Array = [id]
		while not queue.is_empty():
			var current: String = queue.pop_front()
			if visited.has(current) or not regions.has(current):
				continue
			visited[current] = true
			for exit in regions[current].exits:
				queue.append(exit.target)
		if visited.size() != regions.size() or not visited.has("camp"):
			failures.append("Region cannot reach camp and remaining routes: " + str(id))
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MVP content passed: %d regions, %d recipes, %d quests, clear interactions and connected routes" % [regions.size(), recipes.size(), MVPGame.QUEST_IDS.size()])
	quit(0 if failures.is_empty() else 1)
