class_name ItemUseDefinition
extends Resource
## Consumable affordance, not an equippable spell.
enum Kind { COATING, THROWABLE, SPRAY }
@export var id := ""
@export var kind: Kind = Kind.COATING
@export var payload: SpellPayloadData
@export var duration := 1.2
@export var coating_seconds := 60.0
@export var stamina := 0.0
@export var reach := 360.0
@export var splash_radius := 60.0
@export var capacity := 3
func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	if id.is_empty() or not payload or kind not in [Kind.COATING,Kind.THROWABLE,Kind.SPRAY]: errors.append("Missing item action identity/payload")
	for value in [duration,coating_seconds,reach,splash_radius]:
		if not is_finite(value) or value<=0: errors.append("Invalid item action timing/range")
	if not is_finite(stamina) or stamina<0 or capacity<1: errors.append("Invalid item action cost/capacity")
	return errors
