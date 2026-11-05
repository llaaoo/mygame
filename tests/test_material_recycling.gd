extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func run() -> void:
	var supplies := CastingSupplies.new()
	for id in CastingSupplies.MATERIAL_IDS:
		var recipe: CraftingRecipe = supplies.crafting_recipes[id]
		supplies.restore({"amounts": {id: recipe.output_count * 2}})
		var before := supplies.serialize()
		var preview := supplies.recycle_preview(id)
		check(before == supplies.serialize() and preview.costs == {id: recipe.output_count * 2} and preview.returns == recipe.inputs, "Impure or incorrect recycling preview: " + id)
		preview.returns.clear()
		check(not recipe.inputs.is_empty(), "Preview mutated original manufacturing recipe")
		var emissions := [0]
		var count_change := func(): emissions[0] += 1
		supplies.changed.connect(count_change)
		check(supplies.recycle(id) and emissions[0] == 1, "Recycling did not commit once: " + id)
		supplies.changed.disconnect(count_change)
		check(supplies.count(id) == 0, "Recycling consumed wrong batch count: " + id)
		for input in recipe.inputs: check(supplies.count(input) == recipe.inputs[input], "Recycling returned wrong input: " + id)
		before = supplies.serialize()
		check(not supplies.recycle(id) and before == supplies.serialize(), "Insufficient stock recycling changed inventory")
	supplies.restore({"amounts": {"ward_powder": 2}})
	check(supplies.recycle("ward_powder") and supplies.count("ash") == 1 and supplies.count("crystal") == 1 and supplies.count("charcoal") == 0, "Recycling recursively dismantled an intermediate")
	var recipe: CraftingRecipe = supplies.crafting_recipes.frost_salt
	var original := recipe.output_count
	recipe.output_count = 3
	supplies.restore({"amounts": {"frost_salt": 6}})
	check(supplies.recycle_preview("frost_salt").costs == {"frost_salt": 6} and supplies.recycle("frost_salt") and supplies.count("crystal") == 2, "Nonunit output batches multiplied returns")
	recipe.output_count = original
	check(supplies.recycle_preview("unknown").is_empty() and not supplies.recycle("unknown"), "Unknown recipe accepted")
	# Repeated manufacture/recycle always loses resources.
	supplies.restore({"amounts": {"crystal": 8}})
	for i in range(4): check(supplies.craft("frost_salt"), "Manufacturing cycle setup failed")
	for i in range(2): check(supplies.recycle("frost_salt"), "Recycling cycle failed")
	check(supplies.count("crystal") == 4 and supplies.count("frost_salt") == 0, "Craft/recycle cycle generated resources")
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot(true)
	var inventory := game.player.skill_manager.combinations.supplies
	inventory.grant({"frost_salt": 4})
	var before := inventory.serialize()
	check(not game.workshop.recycle("frost_salt") and before == inventory.serialize(), "Broken facility allowed recycling")
	game.progress.claims[AlchemyRepairService.REPAIRED] = true
	check(game.workshop.recycle("frost_salt") and inventory.count("frost_salt") == 2 and inventory.count("crystal") == 2, "Repaired camp did not recycle one batch")
	game._change_region("yard")
	before = inventory.serialize()
	check(not game.workshop.recycle("frost_salt") and before == inventory.serialize(), "Recycling outside camp was accepted")
	check(SaveManager.instance.save_game(2), "Recycling result could not save")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	inventory = game.player.skill_manager.combinations.supplies
	check(game.workshop.recycling_available() and inventory.count("frost_salt") == 2 and inventory.count("crystal") == 2, "Recycling/facility disk recovery failed")
	await fixture.close()
	if errors.is_empty(): print("Material recycling passed: seven recipes, pure previews, original inputs, batch scaling, atomic stock/availability checks, losing cycles and disk restore")
	quit(0 if errors.is_empty() else 1)
