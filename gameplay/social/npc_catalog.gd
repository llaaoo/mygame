class_name NpcCatalog
extends Resource
@export var profiles: Array[NpcProfile]=[]
static var _default: NpcCatalog
static func default_catalog() -> NpcCatalog:
	if not _default: _default=load("res://content/social/catalog.tres") as NpcCatalog
	return _default
func profile(id: String) -> NpcProfile:
	for entry in profiles:
		if entry.actor_id==id: return entry
	return null
func validation_errors() -> Array[String]:
	var errors: Array[String]=[]; var seen: Dictionary={}
	for entry in profiles:
		if not entry or seen.has(entry.actor_id): errors.append("Missing/duplicate NPC"); continue
		seen[entry.actor_id]=true; errors.append_array(entry.validation_errors())
	return errors
