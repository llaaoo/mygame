class_name CharterDefinition
extends Resource
## A deliberate world affiliation. Combat team ownership remains in RelationService.memberships.
@export var id := ""
@export var title := ""
@export_multiline var description := ""
@export var conditions: Array[WorldCondition]=[]
@export var technique_id := ""
func reason(context: ActorContext) -> String:
	var current:=context.relations.affiliation(context.id)
	if not current.is_empty():return "已立誓："+CharterCatalog.default_catalog().definition(current).title
	for condition in conditions:
		if not condition.satisfied(context.learning_query):return condition.hint
	return ""
func enroll(context: ActorContext) -> bool:
	if not reason(context).is_empty():return false
	if not context.martial.learned.has(technique_id) and not context.martial.learn_reason(technique_id).is_empty():return false
	if not context.relations.join_affiliation(context.id,id):return false
	if not context.martial.learned.has(technique_id):context.martial.learn(technique_id)
	context.facts.publish("charter_joined",context.id,{"charter":id,"technique":technique_id})
	return true
func valid() -> bool:
	if id.is_empty() or title.is_empty() or description.is_empty() or not MartialArts.definition(technique_id):return false
	for condition in conditions:
		if not condition or not condition.valid():return false
	return true
