class_name WorldCondition
extends Resource
## Typed, Inspector-authored predicates. No scripts encoded in content strings.
enum Kind { CLAIM, CLEAR, INVENTORY, RELATION, KNOWLEDGE, PRACTICE, AFFILIATION, CIVIL_CLEAR }
enum Knowledge { ANY, ACTION, COMBINATION, MARTIAL, FIELDCRAFT, PERK }
@export var kind: Kind = Kind.CLAIM
@export var key := ""
@export var hint := ""
@export var quantity := 1
@export var knowledge_kind: Knowledge = Knowledge.ANY
@export_enum("neutral","friendly","hostile") var attitude := "neutral"
func satisfied(query: ConditionQuery) -> bool:
	if not query: return false
	match kind:
		Kind.CLAIM: return query.progress and query.progress.claims.has(key)
		Kind.CLEAR: return query.progress and query.progress.cleared.has(key)
		Kind.INVENTORY: return query.items and query.items.count(query.actor_id,key,true)>=quantity
		Kind.RELATION: return query.relations and query.relations.attitude(query.actor_id,key)==attitude
		Kind.KNOWLEDGE: return query.knows(key,knowledge_kind)
		Kind.PRACTICE: return query.fieldcraft!=null and query.fieldcraft.harvest_count(query.actor_id,key)>=quantity
		Kind.AFFILIATION: return query.relations!=null and query.relations.affiliation(query.actor_id)==key
		Kind.CIVIL_CLEAR: return query.law!=null and not query.law.has_reported_debt(query.actor_id)
	return false
func valid() -> bool:
	if kind not in Kind.values() or key.is_empty() or hint.is_empty() or quantity<1 or knowledge_kind not in Knowledge.values(): return false
	if kind==Kind.INVENTORY: return ItemCatalog.default_catalog().definition(key)!=null
	if kind==Kind.PRACTICE: return FieldcraftCatalog.default_catalog().skill(key)!=null
	if kind==Kind.RELATION:return attitude in RelationService.ATTITUDES
	if kind==Kind.AFFILIATION:return CharterCatalog.default_catalog().definition(key)!=null
	if kind==Kind.KNOWLEDGE and knowledge_kind==Knowledge.MARTIAL: return MartialArts.definition(key)!=null
	if kind==Kind.KNOWLEDGE and knowledge_kind==Knowledge.FIELDCRAFT: return FieldcraftCatalog.default_catalog().skill(key)!=null
	if kind==Kind.KNOWLEDGE and knowledge_kind==Knowledge.PERK: return SkillMasteryManager.definitions().has(key)
	return true
