class_name FieldcraftCatalog
extends Resource
@export var skills: Array[FieldcraftSkill]=[]
static var _default: FieldcraftCatalog
static func default_catalog() -> FieldcraftCatalog:
	if not _default: _default=load("res://content/harvesting/fieldcraft.tres") as FieldcraftCatalog
	return _default
func skill(id: String) -> FieldcraftSkill:
	for entry in skills:
		if entry and entry.id==id: return entry
	return null
func validation_errors() -> Array[String]:
	var errors: Array[String]=[];var seen: Dictionary={}
	for entry in skills:
		if not entry or entry.id.is_empty() or entry.title.is_empty() or seen.has(entry.id): errors.append("Invalid/duplicate fieldcraft skill");continue
		seen[entry.id]=true
		for key in entry.costs:
			if not ItemCatalog.default_catalog().definition(str(key)) or not entry.costs[key] is int or entry.costs[key]<1: errors.append("Invalid fieldcraft learning cost: "+entry.id)
		for required in entry.prerequisites:
			if required==entry.id or not skill(required): errors.append("Invalid fieldcraft prerequisite: "+entry.id)
		if _cyclic(entry.id,{}): errors.append("Cyclic fieldcraft prerequisite: "+entry.id)
	return errors
func _cyclic(id: String,visiting: Dictionary) -> bool:
	if visiting.has(id): return true
	var entry:=skill(id)
	if not entry: return false
	var path:=visiting.duplicate();path[id]=true
	for required in entry.prerequisites:
		if _cyclic(required,path): return true
	return false
