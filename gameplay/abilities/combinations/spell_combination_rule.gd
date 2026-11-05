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
@export var consume_stacks := 0
@export var requires_empower := false
@export var required_surface := ""
@export var substitute_material := ""

func condition_label() -> String:
	var parts: Array[String] = []
	if not required_field_type.is_empty():
		parts.append(FireSigil.title_for(required_field_type))
	if not required_caster_status.is_empty():
		parts.append({"echo_ready": "回响印记", "resonant_guard": "共鸣护盾", "soul_charge": "蕴魂"}.get(required_caster_status, required_caster_status))
	if not required_surface.is_empty():
		var medium := "脚下" + SurfaceManager.surface_title(required_surface) + "（消耗1格）"
		if not substitute_material.is_empty():
			var material := load("res://content/casting_materials/%s.tres" % substitute_material) as CastingMaterialData if substitute_material in CastingSupplies.MATERIAL_IDS else null
			medium += "或" + (material.title if material else substitute_material) + "×1"
		parts.append(medium)
	if requires_empower:
		parts.append("Shift")
	return " + ".join(parts)
