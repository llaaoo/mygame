class_name RelationService
extends RefCounted
const ATTITUDES := ["neutral","friendly","hostile"]
var personal: Dictionary = {}
var factions: Dictionary = {}
var memberships: Dictionary = {}
var _dispositions: Dictionary={}
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
	return {"personal":personal.duplicate(),"factions":factions.duplicate(),"memberships":memberships.duplicate(),"dispositions":_dispositions.duplicate()}
func restore(data: Dictionary) -> void:
	personal=data.get("personal",{}).duplicate()
	factions=data.get("factions",{}).duplicate()
	memberships=data.get("memberships",{}).duplicate()
	_dispositions=data.get("dispositions",{}).duplicate()
func disposition(a: String,b: String) -> int:
	return int(_dispositions.get(a+"|"+b,0))
func adjust_disposition(a: String,b: String,amount: int) -> void:
	if a.is_empty() or b.is_empty() or a==b: return
	_dispositions[a+"|"+b]=clampi(disposition(a,b)+amount,-100,100)
	if facts: facts.publish("disposition_changed",a,{"target":b,"value":disposition(a,b)})
func disposition_title(a: String,b: String) -> String:
	var value:=disposition(a,b)
	return "不信任" if value<0 else "信任" if value>=25 else "熟悉" if value>=10 else "初识"
static func valid_dispositions(data: Variant) -> bool:
	if not data is Dictionary or data.size()>1024: return false
	for key in data:
		if not key is String or key.count("|")!=1 or not data[key] is int or data[key]<-100 or data[key]>100: return false
	return true
