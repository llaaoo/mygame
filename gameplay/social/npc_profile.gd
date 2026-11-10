class_name NpcProfile
extends Resource
enum ThreatResponse { RETREAT, DEFEND }
@export var threat_response: ThreatResponse = ThreatResponse.RETREAT
@export var actor_id := ""
@export var region_id := "camp"
@export var role := ""
@export var character: ActorCharacterData
@export var schedule: NPCSchedule
@export var training: TrainingCatalog
@export var market: MarketDefinition
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
	if threat_response not in ThreatResponse.values(): errors.append("Invalid NPC threat response")
	var routine:=daily_schedule()
	if training and training.actor_id!=actor_id: errors.append("Trainer identity mismatch")
	if training: errors.append_array(training.validate())
	if market and (not market.valid() or market.actor_id!=actor_id or market.region_id!=region_id): errors.append("Market identity/configuration mismatch")
	if not routine or routine.entries.is_empty(): errors.append("Missing NPC schedule")
	else:
		for hour in range(24):
			var entry:=routine.get_entry_for_hour(hour+.5)
			if not entry or entry.target_marker not in ["work","rest"]: errors.append("Incomplete NPC schedule")
			var matches:=0
			for shift in routine.entries:
				if not shift or shift.start_hour<0 or shift.end_hour>24 or shift.start_hour>24 or shift.end_hour<0 or shift.start_hour==shift.end_hour: errors.append("Invalid NPC shift"); continue
				var time:=hour+.5
				var covered: bool=(time>=shift.start_hour and time<shift.end_hour) if shift.start_hour<shift.end_hour else (time>=shift.start_hour or time<shift.end_hour)
				if covered: matches+=1
			if matches!=1: errors.append("Overlapping/incomplete NPC shifts")
	for entry in topics:
		if not entry or seen.has(entry.id): errors.append("Missing/duplicate NPC topic"); continue
		seen[entry.id]=true; errors.append_array(entry.validation_errors())
		if entry.kind==NpcTopic.Kind.SERVICE:
			if entry.service in ["trade","production"] and not market: errors.append("NPC service requires its own market: "+entry.id)
			if entry.service=="production" and market and not market.production_services: errors.append("NPC market does not offer production: "+entry.id)
			if entry.service=="training" and not training: errors.append("NPC service requires its own training catalog: "+entry.id)
	return errors
