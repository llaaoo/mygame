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
@export var conditions: Array[WorldCondition]=[]
@export var grants_claims: PackedStringArray=[]
@export var relation_changes: Dictionary={}

func objectives_met(progress: ExplorationProgress) -> bool:
	for condition in conditions:
		if not condition.satisfied(progress.condition_query): return false
	for key in required_claims:
		if not progress.claims.has(key): return false
	for key in required_clears:
		if not progress.cleared.has(key): return false
	return true

func available(progress: ExplorationProgress, stats: StatsComponent) -> bool:
	return (required_attributes.is_empty() or stats!=null and stats.meets_requirements(required_attributes)) and objectives_met(progress)
