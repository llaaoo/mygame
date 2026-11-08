class_name ProductionService
extends RefCounted
## Scheduled intent; no second inventory or prepaid material balance.
var store: InventoryService
var catalog: ProductionCatalog
var seconds_per_hour := 60.0
var _jobs: Dictionary={}
func configure(items: InventoryService,definitions: ProductionCatalog,hour_seconds: float) -> void:
	store=items; catalog=definitions; seconds_per_hour=hour_seconds
func start(id: String,batches := 1) -> OperationResult:
	var definition:=catalog.definition(id)
	if not definition or not definition.valid() or not store.has_container(definition.actor_id+".pack") or batches<1 or batches>20: return OperationResult.reject("invalid_order")
	if _jobs.has(id): return OperationResult.reject("already_scheduled")
	_jobs[id]={"due":store.clock_seconds+definition.work_hours*seconds_per_hour,"batches":batches,"blocked":false}
	_publish("production_scheduled",definition.actor_id,{"id":id,"batches":batches})
	return OperationResult.success()
func cancel(id: String) -> bool:
	if not _jobs.has(id): return false
	_jobs.erase(id); _publish("production_cancelled",catalog.definition(id).actor_id,{"id":id})
	return true
func status(id: String) -> Dictionary:
	var definition:=catalog.definition(id)
	if not definition: return {}
	var job: Dictionary=_jobs.get(id,{})
	var outputs: Dictionary={definition.recipe.output_id:definition.recipe.output_count}
	var result:=store.preview_craft(definition.actor_id,definition.recipe.inputs,outputs)
	return {"scheduled":not job.is_empty(),"remaining":maxf(0,float(job.get("due",store.clock_seconds))-store.clock_seconds),"batches":int(job.get("batches",0)),"blocked":bool(job.get("blocked",false)),"reason":result.reason,"stock":store.count(definition.actor_id,definition.recipe.output_id)}
func advance() -> void:
	for id in _jobs.keys():
		var definition:=catalog.definition(id)
		var job: Dictionary=_jobs[id]
		var outputs: Dictionary={definition.recipe.output_id:definition.recipe.output_count}
		if bool(job.blocked):
			if store.preview_craft(definition.actor_id,definition.recipe.inputs,outputs).accepted:
				job.blocked=false; job.due=store.clock_seconds+definition.work_hours*seconds_per_hour
				_publish("production_resumed",definition.actor_id,{"id":id})
			continue
		while float(job.due)<=store.clock_seconds+.000001 and int(job.batches)>0:
			# Suppress inventory facts until the schedule and stock agree.
			store.begin_batch()
			var result:=store.craft_batch(definition.actor_id,definition.recipe.inputs,outputs)
			if not result.accepted:
				job.blocked=true; store.end_batch(); _publish("production_blocked",definition.actor_id,{"id":id,"reason":result.reason}); break
			job.batches-=1; job.due+=definition.work_hours*seconds_per_hour
			if job.batches==0: _jobs.erase(id)
			store.end_batch()
			_publish("production_completed",definition.actor_id,{"id":id,"remaining_batches":job.batches})
func snapshot() -> Dictionary: return {"schema":1,"jobs":_jobs.duplicate(true)}
func restore(data: Dictionary) -> void:
	if valid_snapshot(data): _jobs=data.get("jobs",{}).duplicate(true)
static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	if data.get("schema")!=1 or not data.get("jobs") is Dictionary or data.jobs.size()>128: return false
	for id in data.jobs:
		var row=data.jobs[id]
		if not id is String or not ProductionCatalog.default_catalog().definition(id) or not row is Dictionary or not row.get("batches") is int or row.batches<1 or row.batches>20 or not row.get("blocked") is bool: return false
		if typeof(row.get("due")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(row.due)) or row.due<0 or row.due>1000000000: return false
	return true

func _publish(kind: String,actor: String,data: Dictionary) -> void:
	if store.facts: store.facts.publish(kind,actor,data)
