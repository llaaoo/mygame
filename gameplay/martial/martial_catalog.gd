class_name MartialCatalog
extends Resource
@export var techniques: Array[MartialTechnique]=[]
# Keep immutable definitions alive; ResourceLoader's cache does not own them.
static var _default: MartialCatalog
static func default_catalog() -> MartialCatalog:
	if not _default: _default=load("res://content/martial/catalog.tres") as MartialCatalog
	return _default

func definition(id: String) -> MartialTechnique:
	for entry in techniques:
		if entry and entry.id==id: return entry
	return null
func ids() -> Array[String]:
	var result: Array[String]=[]
	for entry in techniques:
		if entry: result.append(entry.id)
	return result
func validate() -> Array[String]:
	var errors: Array[String]=[]; var seen: Dictionary={}
	for entry in techniques:
		if not entry or not entry.valid() or seen.has(entry.id): errors.append("Invalid/duplicate martial technique"); continue
		seen[entry.id]=true
	for entry in techniques:
		if entry: _visit(entry,[],{},errors)
	return errors
func _visit(entry: MartialTechnique,path: Array[String],choices: Dictionary,errors: Array[String]) -> void:
	if entry.id in path: errors.append("Cyclic martial prerequisite: "+entry.id); return
	if not entry.exclusive_group.is_empty():
		if choices.has(entry.exclusive_group) and choices[entry.exclusive_group]!=entry.id: errors.append("Conflicting martial prerequisites: "+entry.id); return
		choices[entry.exclusive_group]=entry.id
	var next: Array[String]=path.duplicate(); next.append(entry.id)
	for id in entry.prerequisites:
		var required:=definition(id)
		if not required: errors.append("Unknown martial prerequisite: "+id)
		else: _visit(required,next,choices,errors)
