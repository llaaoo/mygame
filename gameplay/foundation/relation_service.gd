class_name RelationService
extends RefCounted
const ATTITUDES := ["neutral","friendly","hostile"]
var personal: Dictionary = {}
var factions: Dictionary = {}
var memberships: Dictionary = {}
var facts: GameplayFacts
func attitude(a: String,b: String) -> String:
	if a==b: return "friendly"
	var key:=a+"|"+b
	if personal.has(key): return personal[key]
	var fa: String=memberships.get(a,"")
	var fb: String=memberships.get(b,"")
	return "friendly" if not fa.is_empty() and fa==fb else str(factions.get(fa+"|"+fb,"neutral"))
func set_attitude(a: String,b: String,value: String) -> bool:
	if a.is_empty() or b.is_empty() or value not in ATTITUDES: return false
	personal[a+"|"+b]=value
	if facts: facts.publish("relation_changed",a,{"target":b,"attitude":value})
	return true
func snapshot() -> Dictionary:
	return {"personal":personal.duplicate(),"factions":factions.duplicate(),"memberships":memberships.duplicate()}
func restore(data: Dictionary) -> void:
	personal=data.get("personal",{}).duplicate()
	factions=data.get("factions",{}).duplicate()
	memberships=data.get("memberships",{}).duplicate()
