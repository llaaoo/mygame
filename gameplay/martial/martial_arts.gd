class_name MartialArts
extends RefCounted
## Actor-owned knowledge and physical cooldowns. No spell instances or mana costs.
const IDS := ["blade_breaker","spear_thrust","staff_sweep","bow_aim"]
var learned: Dictionary={}
var ready_at: Dictionary={}
static func definition(id: String) -> MartialTechnique:
	return load("res://content/martial/%s.tres"%id) as MartialTechnique if id in IDS else null
func learn(id: String) -> bool:
	if not definition(id) or learned.has(id): return false
	learned[id]=true; return true
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
