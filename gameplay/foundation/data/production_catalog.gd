class_name ProductionCatalog
extends Resource
@export var entries: Array[ProductionDefinition]=[]
# Keep immutable definitions alive; ResourceLoader's cache does not own them.
static var _default: ProductionCatalog
static func default_catalog() -> ProductionCatalog:
	if not _default: _default=load("res://content/production/catalog.tres") as ProductionCatalog
	return _default

func definition(id: String) -> ProductionDefinition:
	for entry in entries:
		if entry and entry.id==id: return entry
	return null
func validate() -> Array[String]:
	var errors: Array[String]=[]; var seen: Dictionary={}
	for entry in entries:
		if not entry or not entry.valid() or seen.has(entry.id): errors.append("Invalid/duplicate production definition"); continue
		seen[entry.id]=true
	return errors
