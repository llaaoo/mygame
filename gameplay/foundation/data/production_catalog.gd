class_name ProductionCatalog
extends Resource
@export var entries: Array[ProductionDefinition]=[]
static func default_catalog() -> ProductionCatalog: return load("res://content/production/catalog.tres") as ProductionCatalog
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
