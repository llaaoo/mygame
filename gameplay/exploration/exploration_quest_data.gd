class_name ExplorationQuestData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
enum Stage { UNDISCOVERED, ACTIVE, READY, REPORTED }

# Introduction clues control discovery, never the right to report earned evidence.
@export var discovery_claims: PackedStringArray = []
@export var unlock_claims: PackedStringArray = []
@export var required_claims: PackedStringArray
@export var required_clears: PackedStringArray
@export var attribute_points := 1
@export var conditions: Array[WorldCondition]=[]
@export var approaches: Array[ExplorationQuestApproachData] = []

func find_approach(approach_id: String) -> ExplorationQuestApproachData:
	for approach in approaches:
		if approach.id == approach_id: return approach
	return null

func stage(progress: ExplorationProgress) -> Stage:
	if progress.claims.has("quest."+id): return Stage.REPORTED
	if is_complete(progress): return Stage.READY
	var introduced := true
	for key in unlock_claims:
		if not progress.claims.has(key): introduced = false
	if introduced: return Stage.ACTIVE
	for key in discovery_claims + required_claims:
		if progress.claims.has(key): return Stage.ACTIVE
	for key in required_clears:
		if progress.cleared.has(key): return Stage.ACTIVE
	return Stage.UNDISCOVERED

func available(progress: ExplorationProgress) -> bool:
	return stage(progress) != Stage.UNDISCOVERED

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
