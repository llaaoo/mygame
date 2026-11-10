class_name ConditionQuery
extends RefCounted
var _progress: WeakRef
var progress: ExplorationProgress:
	get: return _progress.get_ref() as ExplorationProgress if _progress else null
	set(value): _progress=weakref(value) if value else null
var items: InventoryService
var relations: RelationService
var regions: Dictionary={}
var actor_id := "player"
var law: LawService
var fieldcraft: FieldcraftKnowledge
var knowledge_query: Callable
var actor_query: Callable
func stats() -> StatsComponent:
	var actor: Node=actor_query.call(actor_id) if actor_query.is_valid() else null
	return actor.get_node_or_null("StatsComponent") as StatsComponent if is_instance_valid(actor) else null

var catalog: ExplorationContentCatalog
func knows(key: String,kind := WorldCondition.Knowledge.ANY) -> bool:
	if knowledge_query.is_valid(): return bool(knowledge_query.call(actor_id,key,kind))
	return progress!=null and (kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.ACTION] and progress.actions.has(key) or kind in [WorldCondition.Knowledge.ANY,WorldCondition.Knowledge.COMBINATION] and progress.spell_rules.has(key))

func claims_satisfied(keys: PackedStringArray) -> bool:
	for key in keys:
		if not progress or not progress.claims.has(key): return false
	return true

func claims_reason(keys: PackedStringArray) -> String:
	var missing: Array[String] = []
	for key in keys:
		if progress and progress.claims.has(key): continue
		var target: Dictionary = catalog.fact(key) if catalog else {}
		if target.is_empty():
			missing.append("完成相关前置事项")
		else:
			var verb: String = {"discovery":"调查：","pickup":"取得：","objective":"完成："}[target.kind]
			missing.append(verb+str(target.title))
	return "" if missing.is_empty() else "尚需"+"；".join(missing)
