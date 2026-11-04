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

	var progress := ExplorationProgress.new()
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
