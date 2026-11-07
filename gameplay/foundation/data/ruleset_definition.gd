class_name RulesetDefinition
extends Resource
## Mode differences are data. Actors and services never identify a game scene.
@export var material_operations := false
@export var physical_inventory := false
@export var modern_controls := false
@export var field_equipment := false
@export var tactical_combat := false
@export var world_interaction_art := false
@export var maximum_water := 4
@export var pocket_capacity := 12
@export var pack_capacity := 30
@export var carry_limit := 40.0

@export var base_region := "camp"
@export var base_areas: Array[Rect2]=[]
func is_base(region: String,point: Vector2) -> bool:
	if region!=base_region: return false
	if base_areas.is_empty(): return true
	return base_areas.any(func(area: Rect2): return area.has_point(point))
