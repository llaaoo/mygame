class_name WorldCondition
extends Resource
## Typed, Inspector-authored predicates. No scripts encoded in content strings.
enum Kind { CLAIM, CLEAR, INVENTORY, RELATION, KNOWLEDGE }
@export var kind: Kind = Kind.CLAIM
@export var key := ""
@export var hint := ""
@export var quantity := 1
@export_enum("neutral","friendly","hostile") var attitude := "neutral"
func satisfied(query: ConditionQuery) -> bool:
	if not query: return false
	match kind:
		Kind.CLAIM: return query.progress and query.progress.claims.has(key)
		Kind.CLEAR: return query.progress and query.progress.cleared.has(key)
		Kind.INVENTORY: return query.items and query.items.count(query.actor_id,key,true)>=quantity
		Kind.RELATION: return query.relations and query.relations.attitude(query.actor_id,key)==attitude
		Kind.KNOWLEDGE: return query.progress and (query.progress.actions.has(key) or query.progress.spell_rules.has(key))
	return false
