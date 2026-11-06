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
