class_name KillObjective
extends QuestObjective

@export var target_tag: String = "enemy"


func on_event(ev: CombatEvent) -> bool:
	if ev.type != CombatEvent.Type.ON_KILL:
		return false
	if not target_tag.is_empty():
		if ev.target == null or not ev.target.is_in_group(target_tag):
			return false
	current += 1
	return true
