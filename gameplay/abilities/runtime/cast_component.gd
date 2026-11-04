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
var rule_priority := 0
var material_costs: Dictionary = {}
var material_id := ""
var field_bonus := 0.0
var boon_conditions: Array[CastStatusRequirement] = []

func fingerprint() -> Array:
	var requirements: Array = []
	for condition in boon_conditions:
		requirements.append(condition.fingerprint())
	return [rule_id, skill.get_id(), field.get_instance_id() if is_instance_valid(field) else 0, version, status_id, status_version, cost, cooldown, material_id, material_costs.duplicate(), field_bonus, requirements]
