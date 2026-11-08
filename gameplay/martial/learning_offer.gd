class_name LearningOffer
extends Resource
@export var id := ""
@export var technique: MartialTechnique
@export var costs: Dictionary={"coin":8}
@export var requirements: Array[WorldCondition]=[]
func valid() -> bool:
	if id.is_empty() or not technique or not technique.valid(): return false
	for key in costs:
		if not key is String or not ItemCatalog.default_catalog().definition(key) or not costs[key] is int or costs[key]<1 or costs[key]>999: return false
	for condition in requirements:
		if not condition or condition.kind<WorldCondition.Kind.CLAIM or condition.kind>WorldCondition.Kind.KNOWLEDGE or condition.key.is_empty() or condition.hint.is_empty() or condition.quantity<1: return false
		if condition.kind==WorldCondition.Kind.INVENTORY and not ItemCatalog.default_catalog().definition(condition.key): return false
	return true
