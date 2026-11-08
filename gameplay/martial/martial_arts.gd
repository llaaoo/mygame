class_name MartialArts
extends RefCounted
## Actor-owned knowledge and physical cooldowns. No spell instances or mana costs.
static var IDS: Array[String]:
	get: return MartialCatalog.default_catalog().ids()
var catalog: MartialCatalog
var learned: Dictionary={}
var ready_at: Dictionary={}
static func definition(id: String) -> MartialTechnique:
	return MartialCatalog.default_catalog().definition(id)
func learn(id: String) -> bool:
	if not learn_reason(id).is_empty(): return false
	learned[id]=true; return true
func learn_reason(id: String) -> String:
	var definitions:=catalog if catalog else MartialCatalog.default_catalog()
	var data:=definitions.definition(id)
	if not data: return "未知武技"
	if learned.has(id): return "已学会"
	for required in data.prerequisites:
		if not learned.has(required):
			var entry:=definitions.definition(required)
			return "先学习："+(entry.title if entry else "前置武技")
	if not data.exclusive_group.is_empty():
		for known in learned:
			var entry:=definitions.definition(known)
			if entry and entry.exclusive_group==data.exclusive_group: return "已选择互斥专精："+entry.title
	return ""
func reason(id: String,context: ActorContext) -> String:
	var data:=definition(id)
	if not data or not learned.has(id): return "尚未学习武技"
	var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	var weapon:=context.items.equipment_definition(uid)
	if not weapon or not weapon.moveset or weapon.moveset.weapon_type!=data.weapon_type: return "需要对应武器："+str(WeaponMoveset.TITLES.get(data.weapon_type,data.weapon_type))
	if context.items.clock_seconds<float(ready_at.get(id,0)): return "武技尚在冷却"
	return ""
func accepted(id: String,clock: float) -> void: ready_at[id]=clock+definition(id).cooldown
func snapshot() -> Dictionary: return {"learned":learned.duplicate(),"ready_at":ready_at.duplicate()}
func restore(data: Dictionary) -> void:
	learned.clear(); ready_at.clear()
	for id in data.get("learned",{}):
		if id in IDS and data.learned[id]==true: learned[id]=true
	for id in data.get("ready_at",{}):
		if id in IDS and typeof(data.ready_at[id]) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(data.ready_at[id])) and data.ready_at[id]>=0: ready_at[id]=float(data.ready_at[id])
static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("learned",{}) is Dictionary or not data.get("ready_at",{}) is Dictionary: return false
	for id in data.get("learned",{}):
		if id not in IDS or not data.learned[id] is bool: return false
	for id in data.get("ready_at",{}):
		if id not in IDS or typeof(data.ready_at[id]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.ready_at[id])) or data.ready_at[id]<0 or data.ready_at[id]>1000000000: return false
	return true
