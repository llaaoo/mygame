class_name ItemCatalog
extends Resource
@export var items: Array[ItemData]=[]
static var _default: ItemCatalog
static func default_catalog() -> ItemCatalog:
	if not _default: _default=load("res://content/foundation/items.tres") as ItemCatalog
	return _default
func definition(id: String) -> ItemData:
	for item in items:
		if item.id==id: return item
	return null
func equipment() -> Array[EquipmentData]:
	var result: Array[EquipmentData]=[]
	for item in items:
		if item is EquipmentData: result.append(item)
	return result

func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	var seen: Dictionary={}
	for item in items:
		if not item or item.id.is_empty() or seen.has(item.id):
			errors.append("Missing or duplicate item definition")
			continue
		seen[item.id]=true
		if not is_finite(item.weight) or item.weight<0 or item.max_stack<1: errors.append("Invalid item capacity/weight: "+item.id)
		if item is EquipmentData and item.attack_profile and not item.attack_profile.valid(): errors.append("Invalid attack profile: "+item.id)
	return errors
