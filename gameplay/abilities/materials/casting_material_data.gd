class_name CastingMaterialData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
@export var action_ids: PackedStringArray
@export var result_ids: PackedStringArray
@export var extra_mana := 0
@export var field_lifetime_bonus := 0.0
@export var damage_multiplier := 1.0
@export var projectile_speed_multiplier := 1.0
@export var pierce_bonus := 0
@export var projectile_count := 0
@export var spread := 0.0
@export var radius_bonus := 0.0
@export var impact_surface: String
@export var impact_radius := 0.0
@export var impact_duration := 0.0
@export var added_tags: Array[String] = []
@export var buff_duration_bonus := 0.0

func supports(action_id: String, result_id: String) -> bool:
	return action_id in action_ids or result_id in result_ids

func modify(skill: SkillData) -> SkillData:
	var result := skill.create_runtime_variant()
	for tag in added_tags:
		if tag not in result.tags:
			result.tags.append(tag)
	if result.buff_resource and buff_duration_bonus > 0:
		result.buff_duration = maxf(result.buff_duration, result.buff_resource.duration) + buff_duration_bonus
	result.damage = int(round(result.damage * damage_multiplier))
	result.damage_scaling *= damage_multiplier
	result.projectile_speed *= projectile_speed_multiplier
	result.projectile_pierce += pierce_bonus
	if projectile_count > 0:
		result.projectile_count = projectile_count
		result.projectile_spread_degrees = spread
	result.aoe_radius += radius_bonus
	if result.aoe_visual:
		result.aoe_visual.radius += radius_bonus
	if not impact_surface.is_empty():
		result.impact_surface = impact_surface
		result.surface_radius = impact_radius
		result.surface_duration = impact_duration
	return result
