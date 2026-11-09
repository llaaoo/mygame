class_name CraftingRecipe
extends Resource
## Manufacturing produces inventory items. SpellCombinationRule changes a cast result.
@export var id: String
@export var inputs: Dictionary = {}
@export var output_id: String
@export var output_count := 1

@export var ammunition := false
