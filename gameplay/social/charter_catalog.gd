class_name CharterCatalog
extends Resource
@export var entries: Array[CharterDefinition]=[]
static var _default: CharterCatalog
static func default_catalog() -> CharterCatalog:
	if not _default:_default=load("res://content/social/charters/catalog.tres") as CharterCatalog
	return _default
func definition(id: String) -> CharterDefinition:
	for entry in entries:
		if entry.id==id:return entry
	return null
func validation_errors() -> Array[String]:
	var errors: Array[String]=[];var seen: Dictionary={}
	for entry in entries:
		if not entry or not entry.valid() or seen.has(entry.id):errors.append("Invalid/duplicate charter")
		else:seen[entry.id]=true
	return errors
