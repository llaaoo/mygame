class_name ProvisionCatalog
extends Resource
@export var provisions: Array[ProvisionDefinition]=[]
static func default_catalog() -> ProvisionCatalog:
	return load("res://content/provisions/catalog.tres") as ProvisionCatalog
func definition(id: String) -> ProvisionDefinition:
	for entry in provisions:
		if entry and entry.id==id: return entry
	return null
func legacy_projection() -> Dictionary:
	var result: Dictionary={}
	for entry in provisions:
		result[entry.id]={"nutrition":entry.nutrition,"hydration":entry.hydration,"fatigue":entry.fatigue,"seconds":entry.seconds,"duration":entry.effect.duration if entry.effect and not entry.effect.provision_group.is_empty() else 0.0,"text":entry.description}
	return result
func validate() -> Array[String]:
	var errors: Array[String]=[]; var seen: Dictionary={}; var groups: Dictionary={}
	for entry in provisions:
		if not entry or not entry.valid() or seen.has(entry.id): errors.append("Invalid/duplicate provision"); continue
		seen[entry.id]=true
		if not ItemCatalog.default_catalog().definition(entry.id): errors.append("Unknown provision item: "+entry.id)
		if entry.effect and not entry.effect.provision_group.is_empty() and entry.effect.provision_id!=entry.id: errors.append("Provision effect identity mismatch: "+entry.id)
		if entry.effect and not entry.effect.provision_group.is_empty():
			var group:=entry.effect.provision_group
			if groups.has(group) and groups[group]!=entry.effect.exclusive_group: errors.append("Provision group must replace the same slot: "+entry.id)
			groups[group]=entry.effect.exclusive_group
	return errors
