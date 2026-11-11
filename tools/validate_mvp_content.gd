extends SceneTree
func _init() -> void:
	# The public builder checks raw JSON before any template/resource assembly.
	var valley:=GrayriverDefinition.build()
	var raw_errors: PackedStringArray=valley.get_meta("preflight_errors",PackedStringArray())
	if not raw_errors.is_empty():
		for failure in raw_errors: push_error(failure)
		quit(1)
		return
	var catalog := ExplorationContentCatalog.new()
	var failures := ExplorationContentValidator.new().validate(catalog)
	failures.append_array(SkillMasteryManager.validate_catalog())
	var social_facts: Dictionary={}
	for person in GrayriverStories.PEOPLE.values(): social_facts[person.claim]=true
	failures.append_array(NpcCatalog.default_catalog().validation_errors(ExplorationContentCatalog.new(valley),social_facts))
	failures.append_array(ItemCatalog.default_catalog().validation_errors())
	failures.append_array(FieldcraftCatalog.default_catalog().validation_errors())
	failures.append_array(CharterCatalog.default_catalog().validation_errors())
	for id in EquipmentRefit.IDS:
		if not EquipmentRefit.definition(id).valid():failures.append("Invalid equipment refit: "+id)
	failures.append_array(SpellOperationCatalog.default_catalog().validation_errors())
	failures.append_array(ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(valley)))
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MVP content passed: %d regions, %d spell combination rules, %d manufacturing recipes, %d quests, clear interactions and connected routes" % [catalog.regions.size(), catalog.spell_rules.size(), CastingSupplies.new().crafting_recipes.size(), catalog.chapter.quests.size()])
		print("Exploration builds: %d actions, %d fixed equipment rewards" % [catalog.actions.size(), catalog.equipment.size()])
		print("Grayriver content passed: continuous wilderness, %d interior regions, discovered formulas and %d town commissions" % [valley.regions.size()-1,valley.quests.size()])
	quit(0 if failures.is_empty() else 1)
