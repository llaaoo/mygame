extends GutTest
## The registry holds definitions, not a second source of actor knowledge or stock.
func test_all_authored_recipe_files_have_one_registration() -> void:
	var catalog:=CraftingCatalog.default_catalog()
	assert_true(catalog.validation_errors().is_empty())
	var ids: Dictionary={}
	for recipe in catalog.recipes:
		assert_false(ids.has(recipe.id),"Repeated registration: "+recipe.id)
		ids[recipe.id]=true
	for file in DirAccess.get_files_at("res://content/crafting"):
		if not file.ends_with(".tres"): continue
		var resource:=load("res://content/crafting/"+file)
		if resource is CraftingRecipe:
			assert_same(catalog.definition(resource.id),resource,"Unregistered recipe: "+file)
	var supplies:=CastingSupplies.new()
	assert_eq(supplies.crafting_recipes.size(),ids.size())
	for id in ids: assert_same(supplies.crafting_recipes[id],catalog.definition(id))

func test_duplicate_and_missing_recipe_ids_are_rejected() -> void:
	var catalog:=CraftingCatalog.new()
	var first:=CraftingRecipe.new(); first.id="same"
	var second:=CraftingRecipe.new(); second.id="same"
	catalog.recipes=[first,second]
	assert_eq(catalog.validation_errors(),["Duplicate manufacturing recipe ID: same"])
	second.id=""
	assert_eq(catalog.validation_errors(),["Invalid manufacturing recipe registration"])

func test_shared_recipe_definitions_do_not_grant_knowledge_or_share_stock() -> void:
	var first:=CastingSupplies.new(); var second:=CastingSupplies.new()
	first.restrict_crafting=true; second.restrict_crafting=true
	var recipe:=CraftingCatalog.default_catalog().definition("ash")
	var inputs:=recipe.inputs.duplicate(true)
	assert_false(first.knows_recipe(recipe.id))
	assert_false(second.knows_recipe(recipe.id))
	first.known_recipes[recipe.id]=true
	first.grant(inputs)
	assert_true(first.craft(recipe.id))
	assert_eq(first.count(recipe.output_id),recipe.output_count)
	assert_false(second.knows_recipe(recipe.id))
	assert_eq(second.count(recipe.output_id),0)
	assert_eq(recipe.inputs,inputs,"Crafting mutated the shared definition")
	assert_same(first.crafting_recipes[recipe.id],second.crafting_recipes[recipe.id])
