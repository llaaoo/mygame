class_name ExplorationQuestApproachData
extends Resource
## A named, optional way to substantiate the same quest. It never grants the
## discoveries or mechanisms that this approach does not require.
@export var id: String
@export var title: String
@export_multiline var description: String
@export var required_claims: PackedStringArray = []
@export var required_clears: PackedStringArray = []
@export var required_attributes: Dictionary = {}

func objectives_met(progress: ExplorationProgress) -> bool:
	for key in required_claims:
		if not progress.claims.has(key): return false
	for key in required_clears:
		if not progress.cleared.has(key): return false
	return true

func available(progress: ExplorationProgress, stats: StatsComponent) -> bool:
	return stats != null and stats.meets_requirements(required_attributes) and objectives_met(progress)
