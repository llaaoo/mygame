class_name ExplorationQuestData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
@export var required_claims: PackedStringArray
@export var required_clears: PackedStringArray
@export var attribute_points := 1

func is_complete(progress: ExplorationProgress) -> bool:
	for key in required_claims:
		if not progress.claims.has(key):
			return false
	for key in required_clears:
		if not progress.cleared.has(key):
			return false
	return true

func objective_count(progress: ExplorationProgress) -> int:
	var count := 0
	for key in required_claims:
		count += int(progress.claims.has(key))
	for key in required_clears:
		count += int(progress.cleared.has(key))
	return count
