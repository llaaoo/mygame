class_name InteractObjective
extends QuestObjective
@export var target_tag: String = ""
func progress_for_event(event: CombatEvent) -> int:
 if event.type!=CombatEvent.Type.ON_INTERACT: return 0
 return 1 if target_tag.is_empty() or is_instance_valid(event.target) and event.target.is_in_group(target_tag) else 0
func initial_progress(tree: SceneTree) -> int:
 if target_tag.is_empty() or not tree: return 0
 for node in tree.get_nodes_in_group(target_tag):
  if node.has_method("is_opened") and node.is_opened() or node.has_method("is_activated") and node.is_activated(): return required_count
 return 0
