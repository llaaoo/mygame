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
	var definitions: Array[Buff] = []
	var tags: Dictionary = {}
	var fields: Dictionary = {"": true}
	var skills: Array[SkillData] = []
	for file in DirAccess.get_files_at("res://gameplay/abilities/data"):
		if not file.ends_with(".tres"):
			continue
		var resource := load("res://gameplay/abilities/data/" + file)
		var buff := resource as Buff
		var skill := resource as SkillData
		if skill:
			skills.append(skill)
			buff = skill.buff_resource
			for tag in skill.tags:
				tags[tag] = true
		if buff and not buff.status_id.is_empty():
			statuses[buff.status_id] = true
			definitions.append(buff)
	# Include authored resources supplied by this chapter, including test copies.
	for skill in catalog.chapter.actions:
		if skill not in skills: skills.append(skill)
	for rule in catalog.chapter.spell_rules:
		if rule and rule.result_skill and rule.result_skill not in skills: skills.append(rule.result_skill)
	for skill in skills:
		for tag in skill.tags: tags[tag] = true
		var buff := skill.buff_resource
		if buff and not buff.status_id.is_empty():
			statuses[buff.status_id] = true
			if buff not in definitions: definitions.append(buff)
	var runtime_ids := _runtime_skill_ids(catalog)
	for skill in skills:
		_validate_payload(skill, tags)
		for reaction in skill.synergies:
			_validate_reaction(reaction as SkillSynergyData, skill, tags, statuses, runtime_ids, false)
	for buff in definitions:
		if buff.max_stacks < 1 or buff.duration < 0 or buff.capacity_key not in ["", "soul_capacity_bonus"]:
			_fail(buff, "Invalid status capacity/lifetime")
		for id in buff.cleanse_statuses + buff.status_immunities:
			if not statuses.has(id):
				_fail(buff, "Unknown cleansed/protected status: " + id)
		for family in buff.spell_elements:
			if not ElementCatalog.is_core_element(family): _fail(buff, "Unknown boon element family: " + family)
		_validate_surface_reference(buff, "empower_surface", buff.empower_surface, buff.empower_surface_duration, buff.empower_surface_radius)
		if buff.incoming_projectile_multiplier <= 0:
			_fail(buff, "Invalid projectile protection")
	_validate_element_catalogs(tags, statuses)
	var reaction_ids: Dictionary = {}
	for reaction in ElementReactionCatalog.all_rules():
		if not reaction or reaction.id.is_empty() or reaction_ids.has(reaction.id):
			_fail(catalog.chapter, "Invalid/duplicate shared reaction")
			continue
		reaction_ids[reaction.id] = true
		_validate_reaction(reaction, reaction, tags, statuses, runtime_ids, true)
	for action in catalog.chapter.actions:
		if not action or action.get_id().is_empty() or action.combination_only:
			_fail(catalog.chapter, "Invalid equippable action")
			continue
		if action.ground_targeted and (action.skill_type != SkillData.SkillType.AOE or action.cast_distance <= 0):
			_fail(action, "Invalid ground targeting contract")
		_validate_payload(action, tags)
		if action.requires_soul_remnant and (not action.buff_resource or action.soul_harvest_range <= 0 or action.preparation <= 0):
			_fail(action, "Invalid soul harvesting contract")
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
		if rule.required_field_type.is_empty() and rule.required_caster_status.is_empty() and rule.required_surface.is_empty():
			_fail(rule, "Missing combination condition")
		if not rule.required_surface.is_empty() and (rule.required_surface == "dry" or rule.required_surface not in SurfaceCatalog.STATE_IDS):
			_fail(rule, "Unknown preparation surface")
		if not rule.substitute_material.is_empty() and (not supplies.catalog.has(rule.substitute_material) or rule.required_surface.is_empty()):
			_fail(rule, "Invalid preparation material")
		if rule.consume_stacks < 0 or (rule.consume_stacks > 0 and not rule.consume_caster_status):
			_fail(rule, "Invalid consumed stack amount")
		if rule.consume_caster_status and rule.required_caster_status.is_empty():
			_fail(rule, "Missing consumed status")
		var boon := rule.result_skill.buff_resource
		_validate_payload(rule.result_skill, tags)
		if boon and boon.can_empower and (boon.status_id.is_empty() or (boon.spell_tags.is_empty() and boon.spell_elements.is_empty()) or boon.empower_mana_cost < 0 or boon.spell_damage_multiplier <= 0 or boon.empower_damage_multiplier <= 0):
			_fail(rule, "Invalid spell boon")
	for material: CastingMaterialData in supplies.catalog.values():
		_validate_surface_reference(material, "impact_surface", material.impact_surface, material.impact_duration, material.impact_radius)
		if material.extra_mana < 0 or material.damage_multiplier <= 0:
			_fail(material, "Invalid material cost/multiplier")
		for tag in material.added_tags:
			if not tags.has(tag):
				_fail(material, "Unknown material tag: " + tag)
		for tag in material.supported_tags:
			if not tags.has(tag):
				_fail(material, "Unknown material selector: " + tag)
		for type in material.supported_types:
			if type not in [SkillData.SkillType.PROJECTILE, SkillData.SkillType.AOE]:
				_fail(material, "Unsupported material type")
		if material.supported_tags.is_empty() != material.supported_types.is_empty():
			_fail(material, "Incomplete material property selector")
	for recipe: CraftingRecipe in supplies.crafting_recipes.values():
		if recipe.inputs.is_empty() or recipe.output_count <= 0 or not supplies.catalog.has(recipe.output_id):
			_fail(recipe, "Invalid manufacturing output/inputs")
		_validate_materials(recipe, recipe.inputs, supplies)
	if catalog.equipment.size() != catalog.chapter.equipment.size():
		_fail(catalog.chapter, "Duplicate exploration equipment IDs")
	for item in catalog.chapter.equipment:
		if not item or item.id.is_empty() or not item.get_icon_texture() or not item.casting_profile:
			_fail(catalog.chapter, "Invalid exploration equipment")
			continue
		var profile := item.casting_profile
		if absf(profile.preparation_bonus) > 0.5 or profile.soul_capacity_bonus < 0 or profile.soul_capacity_bonus > 5 or absf(profile.field_radius_bonus) > 84 or profile.boon_duration_bonus < -0.75:
			_fail(item, "Equipment profile exceeds supported bounds")
		if profile.medium_infusion_cost < 0 or profile.medium_infusion_cost > 20:
			_fail(item, "Invalid medium infusion cost")
		if profile.partial_boon_mana_cost < 0 or profile.partial_boon_mana_cost > 20:
			_fail(item, "Invalid partial boon cost")
	var claims: Dictionary = {}
	var completion_claims: Dictionary = {}
	var profiles: Dictionary = {}
	var station_ids: Dictionary = {}
	for region in catalog.chapter.regions:
		if not region or region.id.is_empty() or region.title.is_empty():
			_fail(catalog.chapter, "Invalid region")
			continue
		var layout := region.make_layout()
		region.reserve_interaction_space(layout)
		for point in region.interaction_points():
			if not layout.contains_offset(point.pos, 30):
				_fail(region, "Interaction outside arena")
			for obstacle in layout.obstacles:
				if Rect2(obstacle.position - obstacle.size * 0.5, obstacle.size).grow(40).has_point(point.pos):
					_fail(region, "Interaction blocked by geometry")
		for note in region.discoveries:
			_claim(claims, note.id, note)
			completion_claims[note.id] = true
			if note.title.is_empty() or note.text.is_empty():
				_fail(note, "Missing discovery title/text")
			for element in note.element_clues:
				if not ElementCatalog.definition(element): _fail(note, "Unknown clue element")
			for action in note.actions:
				if not catalog.actions.has(action):
					_fail(note, "Unknown action grant: " + action)
			for rule_id in note.spell_rules:
				if not catalog.spell_rules.has(rule_id):
					_fail(note, "Unknown spell combination grant: " + rule_id)
			for id in note.equipment:
				if not catalog.equipment.has(id):
					_fail(note, "Unknown equipment reward: " + id)
			_validate_materials(note, note.materials, supplies)
		for station in region.survival_stations:
			if station.id.is_empty() or station_ids.has(station.id) or station.title.is_empty() or station.kind not in ["water", "cook", "forage"]: _fail(station, "Invalid/duplicate survival station")
			station_ids[station.id] = true
			if station.kind == "forage" and station.harvest.is_empty(): _fail(station, "harvest: empty provisions")
			_validate_materials(station, station.harvest, supplies)
		for facility in region.facilities:
			_claim(claims, facility.id, facility)
			if not facility.start_claim.is_empty(): _claim(claims, facility.start_claim, facility)
			completion_claims[facility.id] = true
			if not facility.start_claim.is_empty(): completion_claims[facility.start_claim] = true
			if facility.title.is_empty() or facility.description.is_empty() or facility.service not in ["recycling", "outpost"]: _fail(facility, "Invalid repair facility")
			if facility.service == "recycling" and (region.id != "camp" or facility.required_claims.is_empty()): _fail(facility, "Invalid camp recycling facility")
			if not facility.assembly or not facility.assembly.validation_error().is_empty(): _fail(facility, "assembly: invalid work method")
			elif facility.service == "recycling" and not facility.assembly.material_costs.is_empty(): _fail(facility, "assembly: recycling repair must remain free")
			else: _validate_materials(facility, facility.assembly.material_costs, supplies)
		for site in region.delivery_sites:
			_claim(claims, site.id, site)
			completion_claims[site.id] = true
			if site.title.is_empty() or site.description.is_empty() or site.methods.is_empty(): _fail(site, "Missing delivery data")
			_validate_materials(site, site.rewards, supplies)
			var method_ids: Dictionary = {}
			for method in site.methods:
				if method: _validate_materials(method, method.material_costs, supplies)
				if not method or not method.validation_error().is_empty() or method.material_costs.is_empty() or method_ids.has(method.id): _fail(site,"Invalid delivery method")
				else:
					method_ids[method.id]=true
		for encounter in region.encounters:
			_validate_enemy_profile(encounter, profiles)
			if encounter.hp <= 0 or encounter.speed <= 0 or encounter.role not in [0, 1, 2]:
				_fail(encounter, "Invalid encounter")
		for event in region.events:
			_claim(claims, event.id, event)
			completion_claims[event.id] = true
			if event.choices.size() < 2:
				_fail(event, "World event requires choices")
			var choices: Dictionary = {}
			for choice in event.choices:
				if choice.id.is_empty() or choices.has(choice.id) or choice.text.is_empty():
					_fail(choice, "Invalid/duplicate world choice")
				choices[choice.id] = true
		for puzzle in region.spell_objects:
			_claim(claims, puzzle.id, puzzle)
			completion_claims[puzzle.id] = true
			if not puzzle.pickup_claim.is_empty():
				_claim(claims, puzzle.pickup_claim, puzzle)
				completion_claims[puzzle.pickup_claim] = true
				if puzzle.pickup_title.is_empty(): _fail(puzzle, "pickup_title: missing part name")
			var method_ids: Dictionary = {}
			for method in puzzle.work_methods:
				if method.id.is_empty() or method_ids.has(method.id) or method.duration <= 0 or not is_finite(method.duration) or method.title.is_empty(): _fail(puzzle, "Invalid/duplicate work method")
				method_ids[method.id] = true
				if not StatsComponent.valid_requirements(method.required_attributes): _fail(method, "Invalid work attribute requirements")
				_validate_materials(method, method.material_costs, supplies)
			if puzzle.routes.is_empty():
				_fail(puzzle, "Missing spell puzzle route")
			for route in puzzle.routes:
				if not route.id.is_empty():
					if method_ids.has(route.id): _fail(puzzle, "Duplicate work/spell method ID")
					method_ids[route.id] = true
				if route.steps.is_empty() and route.required_surface.is_empty():
					_fail(puzzle, "Empty spell puzzle route")
				if not route.required_surface.is_empty() and (route.required_surface not in SurfaceCatalog.STATE_IDS or route.hold_seconds <= 0):
					_fail(puzzle, "Invalid surface puzzle condition")
				for step in route.steps:
					if not tags.has(step):
						_fail(puzzle, "Unknown spell tag: " + step)
			_validate_materials(puzzle, puzzle.materials, supplies)
		for valve in region.valves:
			_claim(claims, valve.id, valve)
			if valve.paths.size() != 2 or valve.title.is_empty(): _fail(valve, "Valve needs two named paths")
			for path in valve.paths:
				if path.points.is_empty() or path.title.is_empty(): _fail(valve, "Invalid water path")
		for patch in region.surface_patches:
			if patch.state not in SurfaceCatalog.STATE_IDS or patch.duration <= 0 or patch.radius < 0: _fail(patch, "Invalid authored surface")
		for prop in region.fixed_props:
			if prop.id.is_empty() or not prop.scene: _fail(prop, "Invalid authored prop")
		for exit in region.exits:
			if not catalog.regions.has(exit.target) or (not exit.required_action.is_empty() and not catalog.actions.has(exit.required_action)):
				_fail(region, "Dangling exit/knowledge requirement")
	# All claims must be collected before checking cross-region exit references.
	var return_points: Array[Vector2] = []
	for region in catalog.chapter.regions:
		for station in region.survival_stations:
			for id in station.required_claims:
				if not completion_claims.has(id): _fail(station, "required_claims: unknown facility marker " + id)
			if not station.cleaned_by_claim.is_empty() and not completion_claims.has(station.cleaned_by_claim): _fail(station, "cleaned_by_claim: unknown completion marker")
		for patch in region.surface_patches:
			if not patch.disabled_by_claim.is_empty() and not completion_claims.has(patch.disabled_by_claim): _fail(patch, "disabled_by_claim: unknown completion marker '%s'" % patch.disabled_by_claim)
		for facility in region.facilities:
			for id in facility.required_claims:
				if not completion_claims.has(id): _fail(facility, "required_claims: unknown facility prerequisite '%s'" % id)
		for event in region.events:
			for id in event.required_claims:
				if not completion_claims.has(id): _fail(event,"Unknown event prerequisite: "+id)
		for site in region.delivery_sites:
			for id in site.required_claims:
				if not completion_claims.has(id): _fail(site,"Unknown delivery prerequisite: "+id)
		for puzzle in region.spell_objects:
			for id in puzzle.required_claims:
				if not completion_claims.has(id): _fail(puzzle, "required_claims: unknown work prerequisite '%s'" % id)
		for exit in region.exits:
			for id in exit.required_claims:
				if not completion_claims.has(id): _fail(exit, "required_claims: unknown completion marker '%s'" % id)
			if not exit.camp_return_title.is_empty():
				if region.id == "camp" or exit.target != "camp" or exit.required_claims.is_empty():
					_fail(exit, "camp_return_title: reverse passage needs a claim-gated camp exit")
				if not exit.camp_return_pos.is_finite() or absf(exit.camp_return_pos.x) > 480 or absf(exit.camp_return_pos.y) > 280:
					_fail(exit, "camp_return_pos: outside camp interaction bounds")
				for point in return_points:
					if point.distance_to(exit.camp_return_pos) < 110: _fail(exit, "camp_return_pos: overlapping reverse passages")
				return_points.append(exit.camp_return_pos)
	for id in SurvivalCatalog.RECIPES:
		var recipe: Dictionary = SurvivalCatalog.RECIPES[id]
		if not SurvivalCatalog.TITLES.has(recipe.output): _fail(catalog.chapter, "Unknown cooking output")
		_validate_materials(catalog.chapter, recipe.inputs, supplies)
		if not str(recipe.unlock).is_empty() and not completion_claims.has(recipe.unlock): _fail(catalog.chapter, "Unknown cooking knowledge")
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
		var approach_ids: Dictionary = {}
		for approach in quest.approaches:
			if approach.id.is_empty() or approach_ids.has(approach.id) or approach.title.is_empty(): _fail(quest, "Invalid/duplicate quest approach")
			approach_ids[approach.id] = true
			if approach.required_attributes.is_empty() or not StatsComponent.valid_requirements(approach.required_attributes): _fail(quest, "Invalid quest attribute requirements")
			if approach.required_claims.is_empty() and approach.required_clears.is_empty(): _fail(quest, "Quest approach needs exploration evidence")
			for id in approach.required_claims:
				if not claims.has(id): _fail(quest, "Missing approach discovery: " + id)
			for id in approach.required_clears:
				if not catalog.regions.has(id): _fail(quest, "Missing approach region: " + id)
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
	# Optional puzzle shortcuts must never replace the original return routes.
	for id in catalog.regions:
		var visited: Dictionary = {}
		var queue: Array = [id]
		while not queue.is_empty():
			var current: String = queue.pop_front()
			if visited.has(current) or not catalog.regions.has(current): continue
			visited[current] = true
			for exit in catalog.regions[current].exits:
				if exit.required_claims.is_empty(): queue.append(exit.target)
		if not visited.has("camp"):
			_fail(catalog.regions[id], "No return to camp without claim-gated exits")
	return failures.duplicate()

func _validate_payload(skill: SkillData, tags: Dictionary) -> void:
	_validate_surface_reference(skill, "creates_surface", skill.creates_surface, skill.surface_duration, skill.surface_radius)
	_validate_surface_reference(skill, "impact_surface", skill.impact_surface, skill.surface_duration, skill.surface_radius)
	if not skill.surface_payload_tags.is_empty() and skill.creates_surface.is_empty() and skill.impact_surface.is_empty():
		_fail(skill, "Surface payload needs a medium")
	for tag in skill.surface_payload_tags:
		if not tags.has(tag):
			_fail(skill, "Unknown surface payload tag: " + tag)

func _validate_element_catalogs(tags: Dictionary, statuses: Dictionary) -> void:
	var seen: Dictionary = {}
	for element in ElementCatalog.all_definitions():
		if element.id not in ElementCatalog.CORE_IDS or seen.has(element.id) or element.title.is_empty():
			_fail(element, "Unknown/duplicate core element")
		seen[element.id] = true
		if not element.parent_id.is_empty(): _fail(element, "Core element cannot have a parent")
		for path in element.hit_status_paths:
			var buff := load(path) as Buff if ResourceLoader.exists(path) else null
			if not buff or not statuses.has(buff.status_id): _fail(element, "Unknown element status")
	for aspect in ElementCatalog.all_aspects():
		if aspect.id not in ElementCatalog.ASPECT_IDS or seen.has(aspect.id) or aspect.title.is_empty(): _fail(aspect, "Unknown/duplicate element aspect")
		seen[aspect.id] = true
		if aspect.parent_id not in ElementCatalog.CORE_IDS: _fail(aspect, "Invalid element aspect parent")
		for path in aspect.hit_status_paths:
			var buff := load(path) as Buff if ResourceLoader.exists(path) else null
			if not buff or not statuses.has(buff.status_id): _fail(aspect, "Unknown element status")
	seen.clear()
	for surface in SurfaceCatalog.all_definitions():
		if surface.id not in SurfaceCatalog.STATE_IDS or seen.has(surface.id) or surface.title.is_empty(): _fail(surface, "Unknown/duplicate surface")
		seen[surface.id] = true
		if surface.danger < 0 or (not surface.expiry_state.is_empty() and surface.expiry_state not in SurfaceCatalog.STATE_IDS):
			_fail(surface, "Invalid surface danger/expiry")
		for path in surface.status_paths:
			var buff := load(path) as Buff if ResourceLoader.exists(path) else null
			if not buff or not statuses.has(buff.status_id): _fail(surface, "Unknown surface status")
		for id in surface.cleanse_statuses + surface.refresh_statuses:
			if not statuses.has(id): _fail(surface, "Unknown surface status")
		if not surface.danger_status.is_empty() and not statuses.has(surface.danger_status): _fail(surface, "Unknown danger status")
	seen.clear()
	for rule in SurfaceCatalog.all_reactions():
		if rule.rule_id.is_empty() or seen.has(rule.rule_id): _fail(rule, "Duplicate surface reaction")
		seen[rule.rule_id] = true
		if rule.required_state not in SurfaceCatalog.STATE_IDS or rule.result_state not in SurfaceCatalog.STATE_IDS or rule.result_duration < 0:
			_fail(rule, "Invalid surface reaction state")
		for tag in rule.required_tags + rule.spread_tags:
			if not tags.has(tag): _fail(rule, "Unknown surface reaction tag: " + tag)
		if not rule.entity_status_path.is_empty():
			var buff := load(rule.entity_status_path) as Buff if ResourceLoader.exists(rule.entity_status_path) else null
			if not buff or not statuses.has(buff.status_id): _fail(rule, "Unknown reaction entity status")

func _claim(claims: Dictionary, id: String, resource: Resource) -> void:
	if id.is_empty() or claims.has(id):
		_fail(resource, "Missing/duplicate stable discovery ID: " + id)
	claims[id] = true

func _validate_materials(resource: Resource, values: Dictionary, supplies: CastingSupplies) -> void:
	for id in values:
		if not CastingSupplies.known_item(str(id)):
			_fail(resource, "Unknown material: " + str(id))
		if not values[id] is int or int(values[id]) <= 0:
			_fail(resource, "Material quantities must be positive integers")

func _validate_entries(chapter: ExplorationChapterData) -> bool:
	var resources: Array = []
	resources.append_array(chapter.equipment)
	resources.append_array(chapter.actions)
	resources.append_array(chapter.spell_rules)
	resources.append_array(chapter.quests)
	for quest in chapter.quests:
		if quest: resources.append_array(quest.approaches)
	for region in chapter.regions:
		resources.append(region)
		if region:
			resources.append_array(region.encounters)
			resources.append_array(region.valves)
			resources.append_array(region.surface_patches)
			resources.append_array(region.fixed_props)
			resources.append_array(region.facilities)
			resources.append_array(region.delivery_sites)
			resources.append_array(region.survival_stations)
			for facility in region.facilities:
				if facility: resources.append(facility.assembly)
			for valve in region.valves:
				if valve: resources.append_array(valve.paths)
			resources.append_array(region.interaction_points())
			for event in region.events:
				if event:
					resources.append_array(event.choices)
			for puzzle in region.spell_objects:
				if puzzle:
					resources.append_array(puzzle.routes)
					resources.append_array(puzzle.work_methods)
	if null in resources:
		_fail(chapter, "Missing content resource reference")
		return false
	return true

func _runtime_skill_ids(catalog: ExplorationContentCatalog) -> Dictionary:
	# Mirror Player's base registrations and MVP's chapter additions. Merely placing
	# a skill file in the authoring directory does not register it at runtime.
	var result: Dictionary = {}
	var template := load("res://gameplay/abilities/registry/player_skill_pool.tres") as SkillPool
	for skill in template.skills:
		if skill: result[skill.get_id()] = true
	for id in Player.PLAYER_SKILL_IDS + ["fire_sigil", "ignite"]:
		var path := "res://gameplay/abilities/data/%s_data.tres" % id
		if not ResourceLoader.exists(path):
			_fail(catalog.chapter, "Runtime skill registration missing: " + path)
			continue
		var skill := load(path) as SkillData
		if skill: result[skill.get_id()] = true
	for skill in catalog.chapter.actions:
		result[skill.get_id()] = true
	for rule in catalog.chapter.spell_rules:
		if rule and rule.result_skill: result[rule.result_skill.get_id()] = true
	return result

func _validate_reaction(reaction: SkillSynergyData, owner: Resource, tags: Dictionary, statuses: Dictionary, runtime_ids: Dictionary, shared: bool) -> void:
	if not reaction:
		_fail(owner, "synergies: invalid SkillSynergyData reference")
		return
	if reaction.id.is_empty() or reaction.bonus_damage_ratio < 0 or reaction.cooldown < 0 or reaction.trigger_chance < 0 or reaction.trigger_chance > 1 or (shared and reaction.required_hit_tags.is_empty()):
		_fail(owner, "Invalid shared reaction properties" if shared else "Invalid skill-specific reaction properties")
	for tag in reaction.required_hit_tags:
		if not tags.has(tag): _fail(reaction, "Unknown %s reaction tag: %s" % ["shared" if shared else "skill-specific", tag])
	for id in [reaction.required_target_status, reaction.required_caster_status]:
		if not id.is_empty() and not statuses.has(id): _fail(reaction, "reaction status: unknown '%s'" % id)
	if not reaction.triggered_skill_id.is_empty() and not runtime_ids.has(reaction.triggered_skill_id):
		_fail(reaction, "triggered_skill_id: unknown runtime skill '%s' (owner %s)" % [reaction.triggered_skill_id, owner.resource_path])

func _validate_surface_reference(owner: Resource, field: String, state: String, duration: float, radius: float) -> void:
	if state.is_empty(): return
	if state not in SurfaceCatalog.STATE_IDS:
		_fail(owner, "%s: unknown surface '%s'" % [field, state])
	if not is_finite(duration) or duration <= 0 or not is_finite(radius) or radius < 0:
		_fail(owner, "%s: invalid duration/radius (%s, %s)" % [field, duration, radius])

func _validate_enemy_profile(encounter: ExplorationEncounterData, profiles: Dictionary) -> void:
	var profile := encounter.profile
	if not profile: return
	if encounter.boss:
		_fail(encounter, "profile: Boss cannot use an ordinary enemy profile '%s'" % profile.id)
	if profile.id.is_empty() or profile.title.is_empty() or profile.appearance_preset not in [0, 1, 2] or profile.role not in [0, 1, 2] or profile.melee_damage <= 0 or not is_finite(profile.melee_cooldown) or profile.melee_cooldown <= 0 or not is_finite(profile.attack_range) or profile.attack_range <= 0 or not is_finite(profile.ranged_preferred_range) or profile.ranged_preferred_range < profile.attack_range:
		_fail(profile, "Invalid enemy profile id/preset/role/combat parameters: " + profile.id)
	for timing in [profile.melee_windup, profile.melee_recovery, profile.ranged_windup]:
		if not is_finite(timing) or timing <= 0 or timing > 2: _fail(profile, "Invalid attack preparation timing: " + str(timing))
	if profiles.has(profile.id) and profiles[profile.id] != profile:
		_fail(profile, "Duplicate enemy profile id: " + profile.id)
	profiles[profile.id] = profile
