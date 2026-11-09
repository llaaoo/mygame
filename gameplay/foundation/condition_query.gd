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

var catalog: ExplorationContentCatalog

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
