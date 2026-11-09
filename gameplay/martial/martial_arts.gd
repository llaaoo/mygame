class_name MartialArts
extends RefCounted
## Actor-owned knowledge and physical cooldowns. No spell instances or mana costs.
static var IDS: Array[String]:
	get: return MartialCatalog.default_catalog().ids()
var catalog: MartialCatalog
var learned: Dictionary={}
var ready_at: Dictionary={}
var _route_loadout: Dictionary={}
var loadout_revision := 0
static func definition(id: String) -> MartialTechnique:
	return MartialCatalog.default_catalog().definition(id)
func learn(id: String) -> bool:
	if not learn_reason(id).is_empty(): return false
	learned[id]=true; _fill_routes(id); return true

static func route_group(data: MartialTechnique,route: MartialRoute) -> String:
	return data.weapon_type+":"+"/".join(route.sequence)
func route_choices() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var definitions:=catalog if catalog else MartialCatalog.default_catalog()
	for data in definitions.techniques:
		if not data or not learned.has(data.id): continue
		for route in data.art_routes:
			result.append({"ref":data.id+"/"+route.id,"technique":data.id,"route":route.id,"group":route_group(data,route),"title":data.followup_profile.title if route.form==MartialRoute.Form.FOLLOWUP else data.title,"definition":route})
	result.sort_custom(func(a,b):
		if a.definition.priority!=b.definition.priority: return a.definition.priority>b.definition.priority
		return str(a.ref)<str(b.ref))
	return result
func _fill_routes(new_id := "") -> void:
	for row in route_choices():
		if not new_id.is_empty() and row.technique!=new_id: continue
		if not _route_loadout.has(row.group): _route_loadout[row.group]=[]
		var slots: Array=_route_loadout[row.group]
		if slots.size()<2 and row.ref not in slots: slots.append(row.ref)
	loadout_revision+=1
func route_slots(group: String) -> Array:
	return _route_loadout.get(group,[]).duplicate()
func route_equipped(id: String,route_id: String) -> bool:
	var data:=definition(id)
	var route:=data.art_route(route_id) if data else null
	return route and id+"/"+route_id in _route_loadout.get(route_group(data,route),[])
func equip_route(reference: String,index: int) -> bool:
	if index<0 or index>1: return false
	for row in route_choices():
		if row.ref!=reference: continue
		var slots:=route_slots(row.group)
		if reference in slots: return slots.find(reference)==index
		if index>slots.size(): return false
		if index==slots.size(): slots.append(reference)
		else: slots[index]=reference
		_route_loadout[row.group]=slots; loadout_revision+=1
		return true
	return false
func remove_route(group: String,index: int) -> bool:
	var slots:=route_slots(group)
	if index<0 or index>=slots.size(): return false
	slots.remove_at(index); _route_loadout[group]=slots; loadout_revision+=1
	return true
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
func snapshot() -> Dictionary: return {"learned":learned.duplicate(),"ready_at":ready_at.duplicate(),"routes":_route_loadout.duplicate(true)}
func restore(data: Dictionary) -> void:
	learned.clear(); ready_at.clear()
	for id in data.get("learned",{}):
		if id in IDS and data.learned[id]==true: learned[id]=true
	for id in data.get("ready_at",{}):
		if id in IDS and typeof(data.ready_at[id]) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(data.ready_at[id])) and data.ready_at[id]>=0: ready_at[id]=float(data.ready_at[id])
	_route_loadout.clear(); _fill_routes()
	if data.has("routes") and valid(data): _route_loadout=data.routes.duplicate(true)
	loadout_revision+=1
static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("learned",{}) is Dictionary or not data.get("ready_at",{}) is Dictionary: return false
	for id in data.get("learned",{}):
		if id not in IDS or not data.learned[id] is bool: return false
	for id in data.get("ready_at",{}):
		if id not in IDS or typeof(data.ready_at[id]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.ready_at[id])) or data.ready_at[id]<0 or data.ready_at[id]>1000000000: return false
	if data.has("routes"):
		if not data.routes is Dictionary or data.routes.size()>64: return false
		for group in data.routes:
			var slots: Variant=data.routes[group]
			if not group is String or not slots is Array or slots.size()>2: return false
			var seen: Dictionary={}
			for reference in slots:
				if not reference is String or seen.has(reference): return false
				seen[reference]=true
				var parts: PackedStringArray=reference.split("/")
				if parts.size()!=2 or not data.get("learned",{}).get(parts[0],false): return false
				var technique:=definition(parts[0]); var route:=technique.art_route(parts[1]) if technique else null
				if not route or route_group(technique,route)!=group: return false
	return true
