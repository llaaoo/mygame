class_name ProductionDefinition
extends Resource
@export var id := ""
@export var actor_id := ""
@export var recipe: CraftingRecipe
@export var work_hours := 1.0
func valid() -> bool:
	if id.is_empty() or actor_id.is_empty() or not recipe or not is_finite(work_hours) or work_hours<=0 or work_hours>24: return false
	if recipe.inputs.is_empty() or recipe.output_count<1 or recipe.output_count>999 or not ItemCatalog.default_catalog().definition(recipe.output_id): return false
	for key in recipe.inputs:
		if not key is String or not ItemCatalog.default_catalog().definition(key) or not recipe.inputs[key] is int or recipe.inputs[key]<1 or recipe.inputs[key]>999: return false
	return true
