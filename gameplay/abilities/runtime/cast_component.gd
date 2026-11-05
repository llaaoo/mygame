class_name CastComponent
extends RefCounted
## A selected result and the conditions/costs needed to accept it.
var skill: SkillData
var rule_id := ""
var cost := 0
var cooldown := 0.0
var preparation := 0.25
var field: FireSigil
var version := -1
var status_id := ""
var status_version := -1
var consume_status := false
var consume_stacks := 0
var rule_priority := 0
var surface_manager: SurfaceManager
var surface_cell := Vector2i.ZERO
var surface_state := ""
var surface_revision := -1
var substitute_material := ""
var material_costs: Dictionary = {}
var material_id := ""
var field_bonus := 0.0
var anchor_to_field := true
var medium_label := ""
var infusion_label := ""
var boon_conditions: Array[CastStatusRequirement] = []

func fingerprint() -> Array:
	var requirements: Array = []
	for condition in boon_conditions:
		requirements.append(condition.fingerprint())
	return [surface_manager.get_instance_id() if is_instance_valid(surface_manager) else 0, surface_cell, surface_state, surface_revision, substitute_material, rule_id, skill.get_id(), field.get_instance_id() if is_instance_valid(field) else 0, version, status_id, status_version, consume_stacks, cost, cooldown, material_id, material_costs.duplicate(), field_bonus, requirements, anchor_to_field, infusion_label, skill.creates_surface, skill.impact_surface, skill.surface_payload_tags.duplicate()]
