class_name InteractObjective
extends QuestObjective

@export var target_tag: String = ""


func on_event(ev: CombatEvent) -> bool:
	if ev.type != CombatEvent.Type.ON_INTERACT:
		return false
	if not target_tag.is_empty():
		if ev.target == null or not ev.target.is_in_group(target_tag):
			return false
	current += 1
	return true


func on_stage_activated(tree: SceneTree) -> void:
	if target_tag.is_empty():
		return
	if tree == null:
		return
	for node in tree.get_nodes_in_group(target_tag):
		if node.has_method("is_opened") and node.is_opened():
			current = required_count
			return
		if node.has_method("is_activated") and node.is_activated():
			current = required_count
			return
