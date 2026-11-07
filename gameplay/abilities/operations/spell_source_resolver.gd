class_name SpellSourceResolver
extends RefCounted
## Resolves only the explicitly chosen source. It never prepares or substitutes one.
static func fields_for(payload: SpellPayloadData,fields: Array[FireSigil],actor: Node2D) -> Array[FireSigil]:
	var found: Array[FireSigil]=[]
	if not payload or payload.source_kind!="field": return found
	for field in fields:
		if field.field_type==payload.source_field and field.is_available_to(actor): found.append(field)
	found.sort_custom(func(a: FireSigil,b: FireSigil): return a.global_position.distance_squared_to(actor.global_position)<b.global_position.distance_squared_to(actor.global_position))
	return found
