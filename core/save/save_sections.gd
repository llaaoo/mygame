class_name SaveSections
extends RefCounted
## Explicit provider registration, independent revisions, validate before restore.
const VERSIONS := "__versions"
enum Status { VALID, INVALID, UNSUPPORTED }
var _providers: Dictionary={}
func register(id: String,provider: Object) -> bool:
	if id.is_empty() or id.begins_with("__") or not is_instance_valid(provider) or not provider.has_method("serialize_save_data") or not provider.has_method("deserialize_save_data"): return false
	if _providers.has(id) and owner_for(id)!=provider: return false
	_providers[id]=provider if provider is RefCounted else weakref(provider)
	return true
func unregister(id: String) -> void: _providers.erase(id)
func clear() -> void: _providers.clear()
func owner_for(id: String) -> Object:
	var value: Variant=_providers.get(id)
	return value.get_ref() if value is WeakRef else value
func revision(id: String) -> int:
	var owner:=owner_for(id)
	return int(owner.call("save_version")) if is_instance_valid(owner) and owner.has_method("save_version") else 1
func capture(base: Dictionary={}) -> Dictionary:
	var result:=base.duplicate(true)
	var versions: Dictionary=result.get(VERSIONS,{}).duplicate(true)
	for id in _providers:
		var owner:=owner_for(id)
		if not is_instance_valid(owner): continue
		result[id]=owner.call("serialize_save_data")
		versions[id]=revision(id)
	if not versions.is_empty(): result[VERSIONS]=versions
	return result
func prepare(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not SaveValues.valid(raw) or not raw.get(VERSIONS,{}) is Dictionary: return {"status":Status.INVALID}
	var result: Dictionary=raw.duplicate(true)
	var versions: Dictionary=result.get(VERSIONS,{}).duplicate(true)
	for id in versions:
		if not id is String or not versions[id] is int or versions[id]<0 or versions[id]>1000000 or not result.has(id): return {"status":Status.INVALID}
	for id in _providers:
		var owner:=owner_for(id)
		if not is_instance_valid(owner): return {"status":Status.INVALID}
		var current:=revision(id);var version:=int(versions.get(id,0)) if result.has(id) else current
		if current<1 or current>1000000: return {"status":Status.INVALID}
		if version>current: return {"status":Status.UNSUPPORTED}
		if not result.get(id,{}) is Dictionary: return {"status":Status.INVALID}
		var data: Dictionary=result.get(id,{}).duplicate(true)
		while version<current:
			if version>0 and not owner.has_method("migrate_save_data"): return {"status":Status.INVALID}
			if owner.has_method("migrate_save_data"):
				var converted: Variant=owner.call("migrate_save_data",data.duplicate(true),version)
				if not converted is Dictionary or not SaveValues.valid(converted): return {"status":Status.INVALID}
				data=converted
			version+=1
		if owner.has_method("save_read_status"):
			var status: int=owner.call("save_read_status",data)
			if status!=Status.VALID: return {"status":status}
		if owner.has_method("validate_save_data") and not owner.call("validate_save_data",data): return {"status":Status.INVALID}
		if result.has(id): result[id]=data;versions[id]=current
	if not versions.is_empty(): result[VERSIONS]=versions
	if _order().size()!=_providers.size(): return {"status":Status.INVALID}
	return {"status":Status.VALID,"data":result}
func restore(raw: Dictionary) -> bool:
	var prepared:=prepare(raw)
	if prepared.status!=Status.VALID: return false
	for id in _order():
		owner_for(id).call("deserialize_save_data",prepared.data.get(id,{}).duplicate(true))
	return true
func _order() -> Array[String]:
	var result: Array[String]=[]
	while result.size()<_providers.size():
		var count:=result.size()
		for id in _providers:
			if id in result: continue
			var owner:=owner_for(id)
			if not is_instance_valid(owner): return []
			var dependencies: PackedStringArray=owner.call("save_dependencies") if owner.has_method("save_dependencies") else PackedStringArray()
			var ready:=true
			for dependency in dependencies:
				if dependency not in result: ready=false
			if ready: result.append(id)
		if result.size()==count: return []
	return result
