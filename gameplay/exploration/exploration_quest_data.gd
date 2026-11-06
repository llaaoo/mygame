class_name ExplorationQuestData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
@export var required_claims: PackedStringArray
@export var required_clears: PackedStringArray
@export var attribute_points := 1
@export var conditions: Array[WorldCondition]=[]
@export var approaches: Array[ExplorationQuestApproachData] = []

func find_approach(approach_id: String) -> ExplorationQuestApproachData:
	for approach in approaches:
		if approach.id == approach_id: return approach
	return null

func can_claim(progress: ExplorationProgress, stats: StatsComponent, approach_id: String = "") -> bool:
	if progress.claims.has("quest." + id): return false
	if approach_id.is_empty(): return is_complete(progress)
	var approach := find_approach(approach_id)
	return approach != null and approach.available(progress, stats)

func has_available_approach(progress: ExplorationProgress, stats: StatsComponent) -> bool:
	for approach in approaches:
		if approach.available(progress, stats): return true
	return false

func is_complete(progress: ExplorationProgress) -> bool:
	for condition in conditions:
		if not condition.satisfied(progress.condition_query): return false
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
