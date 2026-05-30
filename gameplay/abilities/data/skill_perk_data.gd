class_name SkillPerkData
extends Resource

@export var perk_id: String = ""
@export var school: SkillMastery.School = SkillMastery.School.DESTRUCTION
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var required_level: int = 1
@export var cost: int = 1
@export var prerequisite_ids: Array[String] = []
@export var modifier_bonuses: Dictionary = {}
@export var trigger_event: CombatEvent.Type = CombatEvent.Type.ON_KILL
@export var trigger_skill_id: String = ""
@export var trigger_required_tag: String = ""
@export var trigger_required_buff_name: String = ""


func grants_trigger() -> bool:
	return not trigger_skill_id.is_empty()
