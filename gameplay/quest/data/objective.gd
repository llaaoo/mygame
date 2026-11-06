class_name QuestObjective
extends Resource
## Immutable condition definition. QuestRuntime owns every progress counter.
@export var required_count: int = 1
@export var description: String = ""
@export var track_from_start: bool = true
func progress_for_event(_event: CombatEvent) -> int: return 0
func initial_progress(_tree: SceneTree) -> int: return 0
