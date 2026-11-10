class_name NpcTopic
extends Resource
## Authored, immutable conversation knowledge. Service execution stays in its owner.
enum Kind { INFORMATION, SERVICE, FAVOR }
@export var id := ""
@export var title := ""
@export_multiline var response := ""
@export var category := "闲谈"
@export var kind: Kind = Kind.INFORMATION
@export var service := ""
@export var required_claims: PackedStringArray=[]
@export var required_attributes: Dictionary={}
@export var minimum_disposition := -100
@export var recognition := 0
@export var requested_items: Dictionary={}
@export var payment: Dictionary={}
@export var trust_reward := 10
@export var navigation_hints: Array[ExplorationNavigationHint]=[]

func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	if id.is_empty() or "/" in id or title.is_empty() or response.is_empty() or kind not in Kind.values() or minimum_disposition < -100 or minimum_disposition>100: errors.append("Invalid NPC topic")
	if not StatsComponent.valid_requirements(required_attributes): errors.append("Invalid dialogue attributes: "+id)
	if kind==Kind.SERVICE and service not in ["trade","training","production","quests","progression"]: errors.append("Unknown NPC service: "+id)
	if recognition<0 or recognition>10 or recognition>0 and (kind!=Kind.INFORMATION or required_claims.is_empty()): errors.append("Recognition requires an actual world deed: "+id)
	if kind==Kind.FAVOR:
		if requested_items.is_empty() or payment.is_empty() or trust_reward<0 or trust_reward>25: errors.append("Invalid NPC favor: "+id)
		for amounts in [requested_items,payment]:
			for key in amounts:
				if not key is String or not ItemCatalog.default_catalog().definition(key) or not amounts[key] is int or amounts[key]<1 or amounts[key]>99: errors.append("Invalid favor inventory: "+id)
	elif not requested_items.is_empty() or not payment.is_empty(): errors.append("Only favors exchange inventory: "+id)
	return errors
