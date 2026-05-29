class_name QuestObjective
extends Resource

@export var required_count: int = 1
@export var description: String = ""
@export var track_from_start: bool = true

var current: int = 0


func on_event(_ev: CombatEvent) -> bool:
	return false


func on_stage_activated(_tree: SceneTree) -> void:
	pass


func is_completed() -> bool:
	return current >= required_count


func reset() -> void:
	current = 0
