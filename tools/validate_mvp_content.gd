extends SceneTree
func _init() -> void:
	var catalog := ExplorationContentCatalog.new()
	var failures := ExplorationContentValidator.new().validate(catalog)
	var frontier_failures := GrayriverValidator.validate(GrayriverDefinition.data())
	if frontier_failures.is_empty():
		frontier_failures = ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(GrayriverDefinition.build()))
	failures.append_array(frontier_failures)
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MVP content passed: %d regions, %d spell combination rules, %d manufacturing recipes, %d quests, clear interactions and connected routes" % [catalog.regions.size(), catalog.spell_rules.size(), CastingSupplies.new().crafting_recipes.size(), catalog.chapter.quests.size()])
		print("Exploration builds: %d actions, %d fixed equipment rewards" % [catalog.actions.size(), catalog.equipment.size()])
		print("Grayriver content passed: continuous wilderness, 3 interiors, discovered formulas and 6 town commissions")
	quit(0 if failures.is_empty() else 1)
