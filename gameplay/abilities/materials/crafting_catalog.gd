class_name CraftingCatalog
extends Resource
## Shared manufacturing definitions. Learned recipes remain owned by each actor.
@export var recipes: Array[CraftingRecipe]=[]
static var _default: CraftingCatalog
static func default_catalog() -> CraftingCatalog:
	if not _default: _default=load("res://content/crafting/catalog.tres") as CraftingCatalog
	return _default
func definition(id: String) -> CraftingRecipe:
	for recipe in recipes:
		if recipe and recipe.id==id: return recipe
	return null
func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	var seen: Dictionary={}
	for recipe in recipes:
		if not recipe or recipe.id.is_empty():
			errors.append("Invalid manufacturing recipe registration"); continue
		if seen.has(recipe.id): errors.append("Duplicate manufacturing recipe ID: "+recipe.id)
		seen[recipe.id]=true
	return errors
