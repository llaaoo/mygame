class_name ItemUseDefinition
extends Resource
## Consumable affordance, not an equippable spell.
enum Kind { COATING, THROWABLE, SPRAY, CONSUMABLE, BOOK }
@export var technique_id := ""
@export var fieldcraft_skill := ""
@export var id := ""
@export var kind: Kind = Kind.COATING
@export var payload: SpellPayloadData
@export var enchantment: WeaponEnchantment
@export var duration := 1.2
@export var coating_seconds := 60.0
@export var stamina := 0.0
@export var reach := 360.0
@export var splash_radius := 60.0
@export var capacity := 3
func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	if id.is_empty() or (not payload and kind!=Kind.BOOK) or kind not in [Kind.COATING,Kind.THROWABLE,Kind.SPRAY,Kind.CONSUMABLE,Kind.BOOK]: errors.append("Missing item action identity/payload")
	if kind==Kind.BOOK:
		if technique_id.is_empty()==fieldcraft_skill.is_empty(): errors.append("Books require exactly one knowledge source")
		elif not technique_id.is_empty() and not MartialArts.definition(technique_id): errors.append("Invalid technique book")
		elif not fieldcraft_skill.is_empty() and not FieldcraftCatalog.default_catalog().skill(fieldcraft_skill): errors.append("Invalid fieldcraft book")
	if kind==Kind.COATING and (not enchantment or not enchantment.valid()): errors.append("Invalid weapon enchantment")
	for value in [duration,coating_seconds,reach,splash_radius]:
		if not is_finite(value) or value<=0: errors.append("Invalid item action timing/range")
	if not is_finite(stamina) or stamina<0 or capacity<1: errors.append("Invalid item action cost/capacity")
	return errors
