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
	for id in MartialArts.IDS:
		if not MartialArts.definition(id).valid(): errors.append("Invalid martial release: "+id)
	var seen: Dictionary={}
	for item in items:
		if not item or item.id.is_empty() or seen.has(item.id):
			errors.append("Missing or duplicate item definition")
			continue
		seen[item.id]=true
		var art_error:=item.illustration_error()
		if not art_error.is_empty(): errors.append(art_error)
		if not is_finite(item.weight) or item.weight<0 or item.max_stack<1: errors.append("Invalid item capacity/weight: "+item.id)
		if item is EquipmentData and item.attack_profile and not item.attack_profile.valid(): errors.append("Invalid attack profile: "+item.id)
		if item is EquipmentData and item.moveset:
			if not item.moveset.valid(): errors.append("Invalid weapon moveset: "+item.id)
		if item.use_profile:
			var use:=item.use_profile
			errors.append_array(use.validation_errors())
			if use.id!=item.id or (not use.payload and use.kind!=ItemUseDefinition.Kind.BOOK) or not is_finite(use.duration) or use.duration<=0 or use.stamina<0 or not is_finite(use.stamina): errors.append("Invalid item operation: "+item.id)
			if use.kind==ItemUseDefinition.Kind.SPRAY and (item.stackable or item.max_stack!=1 or use.capacity!=3): errors.append("Spray containers must retain individual doses: "+item.id)
			if use.kind==ItemUseDefinition.Kind.COATING and use.payload:
				for status in use.payload.statuses:
					if status.prevents_actions: errors.append("Coatings cannot repeatedly paralyze: "+item.id)
	return errors
