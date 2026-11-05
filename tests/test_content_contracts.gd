extends SceneTree
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _chapter() -> ExplorationChapterData:
	return load("res://content/exploration/chapter.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ExplorationChapterData

func _invalid(chapter: ExplorationChapterData, fragment: String) -> void:
	var messages := ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(chapter))
	_check(fragment in "\n".join(messages), "Content validator missed: " + fragment)

func _run() -> void:
	_check(ExplorationContentValidator.new().validate(ExplorationContentCatalog.new()).is_empty(), "Current content is invalid")
	var chapter := _chapter()
	chapter.regions[0].facilities[0].required_claims.append("missing_repair_claim")
	_invalid(chapter, "unknown facility prerequisite")
	chapter = _chapter()
	chapter.regions[0].facilities[0].assembly = null
	_invalid(chapter, "Missing content resource reference")
	chapter = _chapter()
	chapter.regions[4].surface_patches[0].disabled_by_claim = "missing_pump_claim"
	_invalid(chapter, "disabled_by_claim: unknown")
	chapter = _chapter()
	chapter.quests[3].approaches[0].required_attributes = {"missing_attribute": 14}
	_invalid(chapter, "Invalid quest attribute requirements")
	chapter = _chapter()
	chapter.quests[3].approaches[0].required_clears.append("missing_approach_region")
	_invalid(chapter, "Missing approach region")
	chapter = _chapter()
	chapter.quests[3].approaches[0].required_claims.append("missing_approach_claim")
	_invalid(chapter, "Missing approach discovery")
	chapter = _chapter()
	chapter.quests[3].approaches.append(null)
	_invalid(chapter, "Missing content resource reference")
	chapter = _chapter()
	for region in chapter.regions:
		if region.id == "archive":
			region.exits.back().camp_return_pos = Vector2(9999, 9999)
	_invalid(chapter, "camp_return_pos: outside camp interaction bounds")
	chapter = _chapter()
	for region in chapter.regions:
		if region.id == "archive":
			region.exits.back().required_claims = []
	_invalid(chapter, "camp_return_title: reverse passage needs a claim-gated camp exit")
	chapter = _chapter()
	chapter.regions[0].exits[0].target = "missing_region"
	_invalid(chapter, "Dangling exit")
	chapter = _chapter()
	chapter.regions[0].discoveries[0].spell_rules.append("missing_spell_rule")
	_invalid(chapter, "Unknown spell combination grant")
	chapter = _chapter()
	chapter.spell_rules[0].trigger_action_id = "missing_action"
	_invalid(chapter, "Invalid trigger")
	chapter = _chapter()
	chapter.quests[0].required_claims.append("missing_claim")
	_invalid(chapter, "Missing quest discovery")
	chapter = _chapter()
	chapter.regions[0].discoveries[0].materials = {"ash": -2}
	_invalid(chapter, "positive integers")
	chapter = _chapter()
	chapter.regions[0].spell_objects.append(null)
	_invalid(chapter, "Missing content resource reference")
	chapter = _chapter()
	for region in chapter.regions:
		if not region.spell_objects.is_empty():
			region.spell_objects[0].routes[0].steps = PackedStringArray(["missing_element"])
			break
	_invalid(chapter, "Unknown spell tag")

	chapter = _chapter()
	chapter.equipment[0].casting_profile.preparation_bonus = -2
	_invalid(chapter, "Equipment profile exceeds supported bounds")
	chapter = _chapter()
	chapter.equipment[0].casting_profile.medium_infusion_cost = -1
	_invalid(chapter, "Invalid medium infusion cost")
	chapter = _chapter()
	chapter.actions[0].surface_payload_tags = ["missing_payload_tag"]
	_invalid(chapter, "Unknown surface payload tag")
	_invalid(chapter, "Surface payload needs a medium")
	var material := load("res://content/casting_materials/frost_salt.tres") as CastingMaterialData
	var selectors := material.supported_tags.duplicate()
	material.supported_tags = PackedStringArray(["missing_material_tag"])
	_invalid(_chapter(), "Unknown material selector")
	material.supported_tags = selectors
	var types := material.supported_types.duplicate()
	material.supported_types = [SkillData.SkillType.BUFF]
	_invalid(_chapter(), "Unsupported material type")
	material.supported_types.assign(types)
	chapter = _chapter()
	chapter.regions[0].discoveries[0].equipment.append("missing_equipment")
	_invalid(chapter, "Unknown equipment reward")

	chapter = _chapter()
	chapter.actions[0].ground_targeted = true
	chapter.actions[0].cast_distance = -1
	_invalid(chapter, "Invalid ground targeting contract")
	var reaction := ElementReactionCatalog.all_rules()[0]
	var original_tags := reaction.required_hit_tags.duplicate()
	reaction.required_hit_tags = ["missing_reaction_element"]
	_invalid(_chapter(), "Unknown shared reaction tag")
	reaction.required_hit_tags.assign(original_tags)
	# Known authoring files are not enough: triggered skills must be registered.
	var original_trigger := reaction.triggered_skill_id
	reaction.triggered_skill_id = "__missing_runtime_skill__"
	_invalid(_chapter(), "triggered_skill_id: unknown runtime skill '__missing_runtime_skill__'")
	var details := ExplorationContentValidator.new().validate(ExplorationContentCatalog.new())
	_check(reaction.resource_path in "\n".join(details), "Invalid trigger omitted resource path")
	reaction.triggered_skill_id = original_trigger
	chapter = _chapter()
	var local_reaction := SkillSynergyData.new()
	local_reaction.id = "explicit_test_reaction"
	local_reaction.triggered_skill_id = "__missing_local_skill__"
	chapter.actions[0].synergies = [local_reaction]
	_invalid(chapter, "triggered_skill_id: unknown runtime skill '__missing_local_skill__'")
	local_reaction.triggered_skill_id = "frost_bolt"
	_check(ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(chapter)).is_empty(), "A valid chapter-registered skill or explicit tagless reaction was rejected")
	chapter = _chapter()
	chapter.actions[0].creates_surface = "__missing_created_surface__"
	_invalid(chapter, "creates_surface: unknown surface '__missing_created_surface__'")
	chapter = _chapter()
	chapter.actions[0].impact_surface = "__missing_impact_surface__"
	_invalid(chapter, "impact_surface: unknown surface '__missing_impact_surface__'")
	chapter = _chapter()
	for rule in chapter.spell_rules:
		if rule.result_skill.buff_resource and rule.result_skill.buff_resource.can_empower:
			rule.result_skill.buff_resource.empower_surface = "__missing_boon_surface__"
			break
	_invalid(chapter, "empower_surface: unknown surface '__missing_boon_surface__'")
	var resin := load("res://content/casting_materials/resin.tres") as CastingMaterialData
	var original_surface := resin.impact_surface
	resin.impact_surface = "__missing_material_surface__"
	_invalid(_chapter(), "impact_surface: unknown surface '__missing_material_surface__'")
	resin.impact_surface = original_surface
	var original_duration := resin.impact_duration
	resin.impact_duration = -1
	_invalid(_chapter(), "impact_surface: invalid duration/radius")
	resin.impact_duration = original_duration
	chapter = _chapter()
	chapter.regions[0].exits[0].required_claims = PackedStringArray(["__missing_marker__"])
	_invalid(chapter, "required_claims: unknown completion marker '__missing_marker__'")
	chapter = _chapter()
	for exit in chapter.regions[2].exits:
		exit.required_claims = PackedStringArray(["fire_knowledge"])
	_invalid(chapter, "No return to camp without claim-gated exits")
	chapter = _chapter()
	var enemy_profile := ExplorationEnemyProfile.new()
	enemy_profile.id = "test_guard"
	enemy_profile.title = "测试守卫"
	enemy_profile.melee_cooldown = 0
	chapter.regions[1].encounters[0].profile = enemy_profile
	_invalid(chapter, "Invalid enemy profile")
	enemy_profile.melee_cooldown = 1
	chapter.regions[1].encounters[0].boss = true
	_invalid(chapter, "Boss cannot use an ordinary enemy profile")
	chapter = _chapter()
	for region in chapter.regions:
		if not region.valves.is_empty():
			chapter.regions[0].exits[0].required_claims = PackedStringArray([region.valves[0].id])
			break
	_invalid(chapter, "required_claims: unknown completion marker")
	var progress := ExplorationProgress.new()
	_check(not progress.validate_save_data({"equipment_owned": {"test": 1}}) and not progress.validate_save_data({"equipment_loadout": {"8": {}}}), "Malformed equipment progress accepted")
	var legacy := {"recipes": {"fire_sigil_fireball": true}}
	_check(progress.validate_save_data(legacy), "Legacy spell knowledge no longer validates")
	_check(not progress.validate_save_data({"deaths": {}}) and not progress.validate_save_data({"completed": []}), "Malformed progress primitives accepted")
	progress.deserialize_save_data(legacy)
	_check(progress.spell_rules.has("fire_sigil_fireball"), "Legacy spell knowledge was lost")
	var saved := progress.serialize_save_data()
	_check(saved.has("spell_rules") and not saved.has("recipes"), "New save conflates spell combinations and manufacturing recipes")
	legacy["spell_rules"] = {"frost_sigil_spark": true}
	progress.deserialize_save_data(legacy)
	_check(progress.spell_rules.has("frost_sigil_spark") and not progress.spell_rules.has("fire_sigil_fireball"), "New spell knowledge did not take precedence")

	var supplies := CastingSupplies.new()
	var notifications := [0]
	supplies.changed.connect(func(): notifications[0] += 1)
	_check(not supplies.craft("ash") and notifications[0] == 0, "Rejected manufacturing changed inventory")
	var recipe: CraftingRecipe = supplies.crafting_recipes.ash
	supplies.grant(recipe.inputs)
	notifications[0] = 0
	_check(supplies.craft("ash") and supplies.count(recipe.output_id) == recipe.output_count and notifications[0] == 1, "Manufacturing did not publish one complete inventory change")
	_check(progress.spell_rules == {"frost_sigil_spark": true}, "Manufacturing changed learned spell knowledge")
	if failures.is_empty():
		print("Content contracts passed: negative references, typed puzzle routes, legacy spell knowledge and distinct atomic manufacturing")
	quit(0 if failures.is_empty() else 1)
