extends SceneTree
func _init() -> void:
	var catalog := ExplorationContentCatalog.new()
	var failures := ExplorationContentValidator.new().validate(catalog)
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MVP content passed: %d regions, %d spell combination rules, %d manufacturing recipes, %d quests, clear interactions and connected routes" % [catalog.regions.size(), catalog.spell_rules.size(), CastingSupplies.new().crafting_recipes.size(), catalog.chapter.quests.size()])
	quit(0 if failures.is_empty() else 1)
