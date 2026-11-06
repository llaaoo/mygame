class_name ExplorationExitData
extends Resource

@export var arrival := Vector2.INF
@export var target: String
@export var title: String
@export var pos: Vector2 = Vector2.ZERO
@export var requires_clear: bool = false
@export var required_action: String = ""
@export var required_claims: PackedStringArray = []
@export var locked_message: String = "请先探索并掌握所需知识。"
## Optional reverse entrance, unlocked by the very same existing conditions.
@export var camp_return_title: String = ""
@export var camp_return_pos: Vector2 = Vector2.ZERO

func claims_satisfied(progress: ExplorationProgress) -> bool:
	for id in required_claims:
		if not progress.claims.has(id): return false
	return true
