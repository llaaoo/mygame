class_name SaveFields
extends RefCounted
## Only @export_storage fields opt in. Nodes, services and Callables stay transient.
static var _cache: Dictionary={}
static func schema(owner: RefCounted) -> Dictionary:
	var script:=owner.get_script() as Script
	var id:=script.get_instance_id()
	if _cache.has(id) and _cache[id].script.get_ref()==script: return _cache[id]
	var prototype: RefCounted=script.new()
	var fields: Dictionary={}
	for property in owner.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_STORAGE and int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and not int(property.usage)&PROPERTY_USAGE_EDITOR:
			fields[str(property.name)]=SaveValues.copy(prototype.get(property.name))
	var result: Dictionary={"script":weakref(script),"defaults":fields}
	_cache[id]=result
	return result
static func valid(owner: RefCounted,data: Variant) -> bool:
	if not data is Dictionary or not SaveValues.valid(data): return false
	var defaults: Dictionary=schema(owner).defaults
	for key in data:
		if not key is String: return false
		if defaults.has(key) and not _compatible(defaults[key],data[key]): return false
	return true
static func _compatible(default: Variant,value: Variant) -> bool:
	if typeof(default)==TYPE_FLOAT and typeof(value)==TYPE_INT: return true
	if typeof(default)!=typeof(value): return false
	if default is Dictionary:
		if default.is_typed():
			for key in value:
				if default.get_typed_key_builtin()!=TYPE_NIL and typeof(key)!=default.get_typed_key_builtin(): return false
				if default.get_typed_value_builtin()!=TYPE_NIL and typeof(value[key])!=default.get_typed_value_builtin(): return false
		for key in default:
			if value.has(key) and not _compatible(default[key],value[key]): return false
	elif default is Array and default.is_typed():
		for item in value:
			if typeof(item)!=default.get_typed_builtin(): return false
	return true
static func capture(owner: RefCounted,unknown: Dictionary) -> Dictionary:
	var result:=unknown.duplicate(true)
	for key in schema(owner).defaults: result[key]=SaveValues.copy(owner.get(key))
	return result
static func restore(owner: RefCounted,data: Dictionary) -> Dictionary:
	var unknown:=data.duplicate(true)
	var defaults: Dictionary=schema(owner).defaults
	for key in defaults:
		var value: Variant=_defaults(defaults[key],data.get(key,defaults[key]))
		owner.set(key,value)
		unknown.erase(key)
	return unknown
static func _defaults(default: Variant,value: Variant) -> Variant:
	if default is Dictionary:
		var result: Dictionary=default.duplicate(true)
		result.merge(value.duplicate(true),true)
		for key in default: result[key]=_defaults(default[key],value.get(key,default[key]))
		return result
	if default is Array:
		var result: Array=default.duplicate(true);result.assign(value.duplicate(true))
		return result
	return SaveValues.copy(value)
