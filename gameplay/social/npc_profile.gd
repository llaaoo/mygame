class_name NpcProfile
extends Resource
@export var actor_id := ""
@export var region_id := "camp"
@export var role := ""
@export var character: ActorCharacterData
@export var schedule: NPCSchedule
@export var training: TrainingCatalog
@export var work_position := Vector2.ZERO
@export var rest_position := Vector2.ZERO
@export_multiline var greeting := ""
@export_multiline var familiar_greeting := ""
@export var topics: Array[NpcTopic]=[]
func daily_schedule() -> NPCSchedule:
	return training.schedule if training else schedule
func work_location() -> Vector2:
	return training.work_position if training else work_position
func rest_location() -> Vector2:
	return training.rest_position if training else rest_position
func topic(id: String) -> NpcTopic:
	for entry in topics:
		if entry.id==id: return entry
	return null
func validation_errors() -> Array[String]:
	var errors: Array[String]=[]; var seen: Dictionary={}
	if actor_id.is_empty() or "/" in actor_id or "|" in actor_id or region_id.is_empty() or role.is_empty() or greeting.is_empty() or not character or not work_location().is_finite() or not rest_location().is_finite() or topics.size()>128: errors.append("Invalid NPC profile")
	if character: errors.append_array(character.validation_errors())
	var routine:=daily_schedule()
	if training and training.actor_id!=actor_id: errors.append("Trainer identity mismatch")
	if not routine or routine.entries.is_empty(): errors.append("Missing NPC schedule")
	else:
		for hour in range(24):
			var entry:=routine.get_entry_for_hour(hour+.5)
			if not entry or entry.target_marker not in ["work","rest"]: errors.append("Incomplete NPC schedule")
	for entry in topics:
		if not entry or seen.has(entry.id): errors.append("Missing/duplicate NPC topic"); continue
		seen[entry.id]=true; errors.append_array(entry.validation_errors())
	return errors
