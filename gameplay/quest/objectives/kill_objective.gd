class_name KillObjective
extends QuestObjective
@export var target_tag: String = "enemy"
func progress_for_event(event: CombatEvent) -> int:
 if event.type!=CombatEvent.Type.ON_KILL or not event.data.get("reward_eligible",true): return 0
 return 1 if target_tag.is_empty() or is_instance_valid(event.target) and event.target.is_in_group(target_tag) else 0
