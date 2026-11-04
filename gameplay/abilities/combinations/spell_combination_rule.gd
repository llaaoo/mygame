class_name SpellCombinationRule
extends Resource
## Read-only active rule. Hit synergies remain in SkillSynergyResolver.

@export var id: String
@export var trigger_action_id: String
@export var required_field_type: String
@export var result_skill: SkillData
@export var mana_cost: int = 12
@export var cooldown: float = 2.0
@export var preparation: float = 0.25
@export var priority: int = 0
@export var required_caster_status: String = ""
@export var consume_caster_status := false
@export var requires_empower := false

func condition_label() -> String:
	var parts: Array[String] = []
	if not required_field_type.is_empty():
		parts.append(FireSigil.title_for(required_field_type))
	if not required_caster_status.is_empty():
		parts.append({"echo_ready": "回响印记", "resonant_guard": "共鸣护盾"}.get(required_caster_status, required_caster_status))
	if requires_empower:
		parts.append("Shift")
	return " + ".join(parts)
