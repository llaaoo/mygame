class_name QuickslotLoadout
extends RefCounted
## One binding authority. It owns shortcuts, never inventory or execution.
signal changed(source: String)
const COMBAT_SOURCES := ["left","quick_e","right","slot_0","slot_1","slot_2","slot_3","slot_4","slot_5"]
const ITEM_SOURCES := ["item_0","item_1","item_2","item_3"]
const SOURCES := COMBAT_SOURCES+ITEM_SOURCES
var _bindings: Dictionary={}
var _revisions: Dictionary={}
func revision(source: String) -> int: return int(_revisions.get(source,0))
func instance(source: String) -> SkillInstance:
	return _bindings.get(source,{}).get("skill") as SkillInstance
func selection(source: String) -> Dictionary:
	return _bindings.get(source,{}).get("selection",{}).duplicate(true)
func binding(source: String) -> Dictionary:
	var entry: Dictionary=_bindings.get(source,{})
	var skill:=instance(source)
	if skill: return {"kind":"skill","skill_id":skill.base_data.get_id(),"selection":selection(source)}
	return entry.duplicate(true)
func equip_skill(source: String,skill: SkillData,choice: Dictionary={}) -> bool:
	if source not in SOURCES: return false
	if not skill: return clear(source)
	if not valid_entry({"skill_id":skill.get_id(),"selection":choice}): return false
	_bindings[source]={"skill":SkillInstance.new(skill),"selection":choice.duplicate(true)}
	_touch(source); return true
func set_selection(source: String,choice: Dictionary) -> bool:
	var skill:=instance(source)
	if not skill or not valid_entry({"skill_id":skill.base_data.get_id(),"selection":choice}): return false
	if selection(source)==choice: return true
	# Preserve the instance, upgrades and shared cooldown. Only the source version changes.
	_bindings[source]["selection"]=choice.duplicate(true)
	_touch(source)
	return true
func bind_item(source: String,id: String,uid := "") -> bool:
	if source not in SOURCES: return false
	var definition:=ItemCatalog.default_catalog().definition(id)
	if not definition or not (definition is EquipmentData or definition.use_profile or SurvivalCatalog.FOODS.has(id)): return false
	if (definition is EquipmentData or definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY) and uid.is_empty(): return false
	_bindings[source]={"kind":"item","item_id":id,"uid":uid}
	_touch(source); return true
func bind_technique(source: String,id: String) -> bool:
	if source not in SOURCES or not MartialArts.definition(id): return false
	_bindings[source]={"kind":"technique","technique_id":id}
	_touch(source); return true
func clear(source: String) -> bool:
	if source not in SOURCES: return false
	_bindings.erase(source); _touch(source); return true
func _touch(source: String) -> void:
	_revisions[source]=revision(source)+1
	changed.emit(source)
func snapshot() -> Dictionary:
	var result: Dictionary={}
	for source in SOURCES:
		var skill:=instance(source)
		if skill:
			result[source]=skill.serialize_state()
			result[source]["kind"]="skill"
			var choice:=selection(source)
			if not choice.is_empty(): result[source]["selection"]=choice
		elif not binding(source).is_empty(): result[source]=binding(source)
	return result
static func valid_entry(entry: Variant) -> bool:
	if not entry is Dictionary: return false
	if entry.get("kind","skill") not in ["skill","item","technique"]: return false
	if entry.get("kind","")=="technique": return entry.get("technique_id","") is String and MartialArts.definition(entry.get("technique_id",""))!=null
	if entry.get("kind","")=="item":
		if not entry.get("item_id") is String or not entry.get("uid","") is String: return false
		var definition:=ItemCatalog.default_catalog().definition(entry.item_id)
		if not definition or not (definition is EquipmentData or definition.use_profile or SurvivalCatalog.FOODS.has(entry.item_id)): return false
		return not (definition is EquipmentData or definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.SPRAY) or not entry.get("uid","").is_empty()
	if not entry.get("skill_id","") is String or not entry.get("upgrades",{}) is Dictionary or not entry.get("selection",{}) is Dictionary: return false
	for key in entry.get("selection",{}):
		if key not in ["payload","modifier","uid"] or not entry.selection[key] is String: return false
	var choice: Dictionary=entry.get("selection",{})
	if not choice.is_empty():
		var operation: SpellOperationData
		for candidate in SpellOperationCatalog.default_catalog().operations:
			if candidate.action.get_id()==entry.get("skill_id",""): operation=candidate; break
		if not operation:
			if entry.get("skill_id","") not in ["ignite","pulse","water_call"] or choice.get("payload","")!="" or choice.get("uid","")!="": return false
		elif not operation.payload(str(choice.get("payload",""))): return false
		if choice.get("modifier","")!="" and choice.modifier not in CastingSupplies.MATERIAL_IDS: return false
	for rank in entry.get("upgrades",{}).values():
		if typeof(rank) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(rank)) or rank<0: return false
	return true
