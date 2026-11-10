class_name EquipmentRefit
extends Resource
## Immutable specialization of one actual UID; chosen at its first upgrade.
const IDS: PackedStringArray=["balanced","control","brace","mobile"]
@export var id := ""
@export var title := ""
@export_multiline var description := ""
@export_enum("all","weapon","armor") var category := "all"
@export var extra_costs: Dictionary={}
@export var stat_per_level: Dictionary={}
@export var combat_per_level: Dictionary={}
static var _definitions: Dictionary={}
static func definition(key: String) -> EquipmentRefit:
	if key not in IDS:return null
	if not _definitions.has(key):_definitions[key]=load("res://content/refits/%s.tres"%key) as EquipmentRefit
	return _definitions[key]
func supports(item: EquipmentData) -> bool:
	return item!=null and (category=="all" or (category=="weapon")==bool(item.slot_type==EquipmentData.SlotType.RIGHT_HAND))
func valid() -> bool:
	if id not in IDS or title.is_empty() or description.is_empty() or category not in ["all","weapon","armor"]:return false
	for key in extra_costs:
		if not ItemCatalog.default_catalog().definition(str(key)) or not extra_costs[key] is int or extra_costs[key]<1 or extra_costs[key]>20:return false
	for key in stat_per_level:
		if key not in ["attack_damage","max_hp","move_speed"] or typeof(stat_per_level[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(stat_per_level[key])):return false
	for key in combat_per_level:
		if key not in ["impact_bonus","weapon_stamina_cost","impact_resistance","stamina_recovery","dodge_cost"] or typeof(combat_per_level[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(combat_per_level[key])):return false
	return true
