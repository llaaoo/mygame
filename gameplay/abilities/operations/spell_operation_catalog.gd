class_name SpellOperationCatalog
extends Resource
@export var operations: Array[SpellOperationData]=[]
@export var rules: Array[SpellCombinationRule]=[]
@export var recipes: Array[CraftingRecipe]=[]
static var _default: SpellOperationCatalog
static func default_catalog() -> SpellOperationCatalog:
	if not _default: _default=load("res://content/spell_operations/catalog.tres") as SpellOperationCatalog
	return _default
func operation(id: String) -> SpellOperationData:
	for entry in operations:
		if entry.action.operation_id==id: return entry
	return null
func canonical(id: String) -> String:
	for entry in operations:
		if id in entry.aliases: return entry.action.get_id()
	return id
func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	var ids: Dictionary={}
	for entry in operations:
		if not entry or not entry.action or entry.action.operation_id.is_empty():
			errors.append("Invalid spell operation"); continue
		if ids.has(entry.action.get_id()): errors.append("Duplicate operation")
		ids[entry.action.get_id()]=true
		if entry.action.mp_cost<0 or not is_finite(entry.action.cooldown) or entry.action.cooldown<=0 or not is_finite(entry.action.preparation) or entry.action.preparation<0: errors.append("Invalid operation costs/timing")
		var payload_ids: Dictionary={}
		for medium in entry.payloads:
			if not medium or medium.id.is_empty() or payload_ids.has(medium.id):
				errors.append("Duplicate/invalid payload"); continue
			payload_ids[medium.id]=true
			if not entry.action.field_type.is_empty() and medium.field_type.is_empty(): errors.append("Inscription payload needs a field type")
			if entry.action.field_type.is_empty() and medium.material_id.is_empty(): errors.append("Dispersal cannot invent a substance")
			if not medium.surface.is_empty() and medium.surface not in SurfaceCatalog.STATE_IDS: errors.append("Unknown payload surface")
			for status in medium.statuses:
				if not status is Buff or status.status_id.is_empty() or not is_finite(status.duration) or status.duration<=0 or status.tick_damage<0: errors.append("Invalid payload status")
			if medium.quantity<1 or medium.extra_mana<0 or medium.damage<0 or not is_finite(medium.damage_scaling) or medium.damage_scaling<0: errors.append("Invalid payload quantity/damage")
			if not medium.material_id.is_empty() and not ItemCatalog.default_catalog().definition(medium.material_id): errors.append("Unknown payload item: "+medium.material_id)
			if not is_finite(medium.field_duration) or medium.field_duration<=0 or medium.field_charges<1 or not is_finite(medium.surface_duration) or medium.surface_duration<=0: errors.append("Invalid payload duration/charges")
		if not entry.default_payload.is_empty() and not payload_ids.has(entry.default_payload): errors.append("Unknown default payload")
	return errors
