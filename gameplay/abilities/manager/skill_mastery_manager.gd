class_name SkillMasteryManager
extends Node

signal mastery_xp_gained(skill_id: String, school: int, xp_amount: float, level: int, progress: float)
signal mastery_leveled(skill_id: String, school: int, new_level: int)
signal character_leveled(new_level: int)
signal perk_points_changed(school: int, points: int)
signal perk_unlocked(school: int, perk_id: String)

const LEVELS_PER_CHAR_LEVEL: int = 3 # Legacy serialization only; StatsComponent owns level.
const XP_DAMAGE_SCALE: float = 0.5
const XP_BUFF_BASE: float = 10.0
const XP_SUMMON_BASE: float = 15.0
const XP_CHANNEL_TICK: float = 2.0
const XP_KILL_BONUS: float = 5.0
const MODIFIER_KEYS := ["buff.duration.all", "buff.ice_armor.duration", "carry.maximum", "combat.counter_damage", "combat.impact", "cooldown.dash", "craft.ammunition", "damage.all", "damage.fire", "damage.ice", "damage.lightning", "damage.shadow", "harvest.herbs", "mana_cost.all", "mana_cost.fire", "mana_cost.ice", "mana_cost.shadow", "rest.fatigue", "salvage.scrap", "stamina.art", "stamina.attack", "stamina.dodge", "stamina.guard", "stamina.guarding_regen", "stamina.maximum", "stamina.regeneration", "stamina.sprint", "status.burning_duration", "status.frozen_duration", "status.poison_duration", "summon.damage_multiplier", "summon.duration_multiplier", "summon.hp_multiplier", "summon.max_count", "survival.fed_regen", "survival.needs", "upgrade.coin_discount", "work.duration"]
const ICE_ARMOR_NAME := "ice_armor"
const TREE_RESOURCE_PATHS := {
	SkillMastery.School.DESTRUCTION: "res://gameplay/abilities/data/trees/destruction_tree.tres",
	SkillMastery.School.CONJURATION: "res://gameplay/abilities/data/trees/conjuration_tree.tres",
	SkillMastery.School.RESTORATION: "res://gameplay/abilities/data/trees/restoration_tree.tres",
	SkillMastery.School.ALTERATION: "res://gameplay/abilities/data/trees/alteration_tree.tres",
	SkillMastery.School.ILLUSION: "res://gameplay/abilities/data/trees/illusion_tree.tres",
	SkillMastery.School.MELEE: "res://gameplay/abilities/data/trees/melee_tree.tres",
	SkillMastery.School.DEFENSE: "res://gameplay/abilities/data/trees/defense_tree.tres",
	SkillMastery.School.CRAFTING: "res://gameplay/abilities/data/trees/crafting_tree.tres",
	SkillMastery.School.SURVIVAL: "res://gameplay/abilities/data/trees/survival_tree.tres",
}

var _masteries: Dictionary = {}
var _trees: Dictionary = {}
var _perk_catalog: Dictionary = {}
var _tree_resources: Dictionary = {}
var _unlocked_perks: Dictionary = {}
var _legacy_credit := 0
var revision := 0
var _total_mastery_levels: int = 0
var _owner_entity: Node = null


func setup(owner: Node = null) -> void:
	_owner_entity = owner
	for school in TREE_RESOURCE_PATHS:
		_ensure_mastery(school)
		_trees[school] = _load_tree_for_school(school)
		_unlocked_perks[school] = []
	_perk_catalog=definitions()
	var stats:=_stats()
	if stats and not stats.leveled_up.is_connected(_on_character_level): stats.leveled_up.connect(_on_character_level)
	_recompute_totals()


func _ensure_mastery(school: SkillMastery.School) -> SkillMastery:
	if _masteries.has(school):
		return _masteries[school]
	var mastery := SkillMastery.new()
	mastery.school = school
	mastery.skill_id = SkillMastery.School.keys()[school]
	_masteries[school] = mastery
	return mastery


func get_mastery(school: SkillMastery.School) -> SkillMastery:
	return _masteries.get(school, null) as SkillMastery


func get_character_level() -> int:
	return _stats().level if _stats() else 1


func get_all_masteries() -> Array[SkillMastery]:
	var result: Array[SkillMastery] = []
	for mastery in _masteries.values():
		result.append(mastery)
	return result


func get_perks_for_school(school: SkillMastery.School) -> Array[SkillPerkData]:
	var result: Array[SkillPerkData] = []
	for perk in _trees.get(school, []):
		result.append(perk as SkillPerkData)
	return result


func get_tree_data(school: SkillMastery.School) -> SkillTreeData:
	return _tree_resources.get(school, null) as SkillTreeData


func get_spells_for_school(school: SkillMastery.School) -> Array[SkillData]:
	var result: Array[SkillData] = []
	var player := _owner_entity as Player
	if not player or not player.skill_manager or not player.skill_manager.pool:
		return result
	for skill in player.skill_manager.pool.skills:
		if skill and player.skill_manager.material_operations and SpellOperationCatalog.default_catalog().canonical(skill.get_id())!=skill.get_id(): continue
		if skill and skill.school == school:
			result.append(skill)
	result.sort_custom(func(a: SkillData, b: SkillData):
		if a.tier == b.tier:
			return a.display_name < b.display_name
		return a.tier < b.tier
	)
	return result


func get_spell_unlock_level(skill: SkillData) -> int:
	if not skill:
		return 1
	return [1, 5, 10, 20, 30][clampi(skill.tier - 1, 0, 4)]


func is_spell_unlocked(skill: SkillData) -> bool:
	var mastery := get_mastery(skill.school) if skill else null
	return mastery != null and mastery.level >= get_spell_unlock_level(skill)


func get_unlocked_perks_for_school(school: SkillMastery.School) -> Array[String]:
	var result: Array[String] = []
	for perk_id in _unlocked_perks.get(school, []):
		result.append(str(perk_id))
	return result


func get_available_perk_points(_school: int = -1) -> int:
	var spent:=0
	for ids in _unlocked_perks.values():
		for id in ids:
			var perk:=_find_perk(id)
			if perk: spent+=perk.cost
	return maxi(0,get_character_level()-1+_legacy_credit-spent)

func _stats() -> StatsComponent:
	return _owner_entity.get_node_or_null("StatsComponent") as StatsComponent if is_instance_valid(_owner_entity) else null

func _on_character_level(level: int) -> void:
	character_leveled.emit(level)
	if is_instance_valid(_owner_entity) and "actor_context" in _owner_entity and _owner_entity.actor_context and _owner_entity.actor_context.facts: _owner_entity.actor_context.facts.publish("character_leveled",_owner_entity.actor_context.id,{"level":level})
	perk_points_changed.emit(-1,get_available_perk_points())

func unlock_reason(perk_id: String) -> String:
	var perk:=_find_perk(perk_id)
	if not perk: return "未知Perk"
	if has_perk(perk_id): return "已学习"
	if _owner_entity and _owner_entity.get_node("HealthComponent").is_dead: return "死亡时无法学习"
	if get_character_level()<perk.required_character_level: return "需要角色等级%d"%perk.required_character_level
	var mastery:=get_mastery(perk.school)
	if not mastery or mastery.level<perk.required_level: return "需要分支熟练度%d"%perk.required_level
	for key in perk.required_attributes:
		if not _stats() or int(_stats().get(key))<int(perk.required_attributes[key]): return "需要基础%s%d"%[StatsComponent.primary_title(key),perk.required_attributes[key]]
	for id in perk.prerequisite_ids:
		if not has_perk(id): return "先学习："+_find_perk(id).display_name
	if get_available_perk_points()<perk.cost: return "Perk点数不足"
	return ""


func has_perk(perk_id: String) -> bool:
	for school in _unlocked_perks.keys():
		var unlocked: Array = _unlocked_perks[school]
		if perk_id in unlocked:
			return true
	return false


func get_perk(perk_id: String) -> SkillPerkData:
	return _find_perk(perk_id)


func unlock_perk(perk_id: String) -> bool:
	if not unlock_reason(perk_id).is_empty(): return false
	var perk:=_find_perk(perk_id)
	var unlocked: Array=_unlocked_perks[perk.school]
	unlocked.append(perk_id); revision+=1
	if _owner_entity.has_method("_apply_stats"): _owner_entity._apply_stats()
	perk_points_changed.emit(-1,get_available_perk_points())
	perk_unlocked.emit(perk.school,perk_id)
	if "actor_context" in _owner_entity and _owner_entity.actor_context and _owner_entity.actor_context.facts: _owner_entity.actor_context.facts.publish("perk_learned",_owner_entity.actor_context.id,{"perk":perk_id})
	return true

func can_unlock_perk(perk_id: String) -> bool:
	return unlock_reason(perk_id).is_empty()


func get_modifier_value(key: String, default_value: float = 0.0) -> float:
	var value:=default_value
	for ids in _unlocked_perks.values():
		for id in ids:
			var perk:=_find_perk(id)
			if perk: value+=float(perk.modifier_bonuses.get(key,0))
	return value


func get_unlocked_trigger_perks() -> Array[SkillPerkData]:
	var result: Array[SkillPerkData] = []
	for school in _trees.keys():
		for perk in _trees[school]:
			if has_perk(perk.perk_id) and perk.grants_trigger():
				result.append(perk)
	return result


func build_trigger_effect(perk: SkillPerkData) -> GenericTriggeredCast:
	if not perk or not perk.grants_trigger():
		return null
	var trigger := GenericTriggeredCast.new()
	trigger.trigger_type = perk.trigger_event
	trigger.scope_source = "perk"
	trigger.max_recursion = 0
	trigger.cast_skill_id = perk.trigger_skill_id
	trigger.caster_mode = GenericTriggeredCast.CasterMode.PLAYER
	trigger.target_mode = GenericTriggeredCast.TargetMode.EVENT_TARGET
	trigger.consume_mp = false

	var conditions: Array[Condition] = []
	if not perk.trigger_required_tag.is_empty():
		var skill_cond := SkillTagCondition.new()
		skill_cond.required_skill_tag = perk.trigger_required_tag
		conditions.append(skill_cond)
	if not perk.trigger_required_buff_name.is_empty():
		var buff_cond := BuffNameCondition.new()
		buff_cond.required_buff_name = perk.trigger_required_buff_name
		conditions.append(buff_cond)
	trigger.conditions = conditions
	return trigger


func serialize_state() -> Dictionary:
	var masteries: Dictionary = {}
	for school in _masteries.keys():
		var mastery: SkillMastery = _masteries[school]
		masteries[str(school)] = {
			"level": mastery.level,
			"xp": mastery.xp,
			"xp_to_next": mastery.xp_to_next,
			"perk_points": mastery.perk_points,
		}
	var unlocked: Dictionary = {}
	for school in _unlocked_perks.keys():
		var perk_ids: Array[String] = []
		for perk_id in _unlocked_perks[school]:
			perk_ids.append(str(perk_id))
		unlocked[str(school)] = perk_ids
	return {
		"schema": 2,
		"legacy_credit": _legacy_credit,
		"character_level": get_character_level(),
		"total_mastery_levels": _total_mastery_levels,
		"masteries": masteries,
		"unlocked_perks": unlocked,
	}


func restore_state(data: Dictionary) -> void:
	if not valid_state(data,get_character_level()): return
	# Full replacement, so in-place F9 cannot retain a later purchase or mastery.
	_masteries.clear(); _unlocked_perks.clear()
	for school in TREE_RESOURCE_PATHS:
		var mastery:=_ensure_mastery(school)
		var raw: Dictionary=data.get("masteries",{}).get(str(school),data.get("masteries",{}).get(school,{}))
		mastery.level=int(raw.get("level",1)); mastery.xp=float(raw.get("xp",0)); mastery.xp_to_next=float(raw.get("xp_to_next",15))
		_unlocked_perks[school]=data.get("unlocked_perks",{}).get(str(school),data.get("unlocked_perks",{}).get(school,[])).duplicate()
	_legacy_credit=int(data.get("legacy_credit",0))
	if int(data.get("schema",1))<2:
		var old_budget:=0
		for raw in data.get("masteries",{}).values(): old_budget+=int(raw.get("perk_points",0))
		for ids in _unlocked_perks.values():
			for id in ids: old_budget+=_find_perk(id).cost
		_legacy_credit=maxi(0,old_budget-(get_character_level()-1))
	revision+=1; _recompute_totals()
	if _owner_entity.has_method("_apply_stats"): _owner_entity._apply_stats()


func on_skill_cast(skill: SkillData) -> void:
	if not skill:
		return
	var school := _guess_school(skill)
	var mastery := _ensure_mastery(school)
	var amount := XP_BUFF_BASE
	match skill.skill_type:
		SkillData.SkillType.PROJECTILE, SkillData.SkillType.AOE:
			amount = maxf(1.0, skill.damage * XP_DAMAGE_SCALE * 0.3)
		SkillData.SkillType.SUMMON:
			amount = XP_SUMMON_BASE
		SkillData.SkillType.BUFF:
			amount = XP_BUFF_BASE
		SkillData.SkillType.DASH:
			amount = 5.0
	_add_xp(mastery, amount)


func on_deal_damage(school: SkillMastery.School, damage: int) -> void:
	var mastery := _masteries.get(school) as SkillMastery
	if not mastery:
		return
	_add_xp(mastery, damage * XP_DAMAGE_SCALE)


func on_channel_tick(school: SkillMastery.School) -> void:
	var mastery := _masteries.get(school) as SkillMastery
	if not mastery:
		return
	_add_xp(mastery, XP_CHANNEL_TICK)


func on_kill(school: SkillMastery.School) -> void:
	var mastery := _masteries.get(school) as SkillMastery
	if not mastery:
		return
	_add_xp(mastery, XP_KILL_BONUS)


func _add_xp(mastery: SkillMastery, amount: float) -> void:
	if amount <= 0 or not is_finite(amount): return
	if is_instance_valid(_owner_entity) and "actor_context" in _owner_entity and _owner_entity.actor_context and not _owner_entity.actor_context.reward_eligible: return
	var old_level:=mastery.level
	var leveled:=mastery.add_xp(minf(amount,1000000))
	mastery.perk_points=0 # Legacy local fields are never another spendable budget.
	_recompute_totals()
	if leveled and _stats(): _stats().add_experience((mastery.level-old_level)*25)
	mastery_xp_gained.emit(mastery.skill_id,mastery.school,amount,mastery.level,mastery.get_progress())
	if leveled: mastery_leveled.emit(mastery.skill_id,mastery.school,mastery.level)


func _recompute_totals() -> void:
	_total_mastery_levels = 0
	for mastery in _masteries.values():
		_total_mastery_levels += max(0, mastery.level - 1)


func _guess_school(skill: SkillData) -> SkillMastery.School:
	return skill.school


func _find_perk(perk_id: String) -> SkillPerkData:
	return _perk_catalog.get(perk_id) as SkillPerkData


func _load_tree_for_school(school: SkillMastery.School) -> Array[SkillPerkData]:
	var path: String = TREE_RESOURCE_PATHS.get(school, "")
	if not path.is_empty():
		var tree_resource: Resource = load(path)
		if tree_resource and "perks" in tree_resource:
			_tree_resources[school] = tree_resource
			var perks: Array[SkillPerkData] = []
			for perk in tree_resource.get("perks"):
				var perk_resource := perk as SkillPerkData
				if perk_resource:
					perks.append(perk_resource)
			return perks
	return []


func record_activity(kind: String,amount := 1.0) -> void:
	var school: int={"melee_hit":SkillMastery.School.MELEE,"hit_blocked":SkillMastery.School.DEFENSE,"recipe_crafted":SkillMastery.School.CRAFTING,"field_work":SkillMastery.School.CRAFTING,"resource_harvested":SkillMastery.School.SURVIVAL,"corpse_harvested":SkillMastery.School.SURVIVAL,"discovery":SkillMastery.School.SURVIVAL,"equipment_upgraded":SkillMastery.School.CRAFTING,"equipment_dismantled":SkillMastery.School.CRAFTING}.get(kind,-1)
	if school<0 or amount<=0: return
	_add_xp(_ensure_mastery(school),amount)
func activity_efficiency(school: SkillMastery.School) -> float:
	var mastery:=_masteries.get(school) as SkillMastery
	return clampf(1.0-(mastery.level-1)*.005,.85,1.0) if mastery else 1.0

func requirement_text(perk: SkillPerkData) -> String:
	var parts:=PackedStringArray(["角色%d级"%perk.required_character_level,"分支熟练度%d"%perk.required_level,"花费%d点"%perk.cost])
	for key in perk.required_attributes: parts.append("基础%s%d"%[StatsComponent.primary_title(key),perk.required_attributes[key]])
	for id in perk.prerequisite_ids: parts.append("前置："+_find_perk(id).display_name)
	return " · ".join(parts)

static func definitions() -> Dictionary:
	var result: Dictionary={}
	for path in TREE_RESOURCE_PATHS.values():
		var tree:=load(path) as SkillTreeData
		if tree:
			for perk: SkillPerkData in tree.perks: result[perk.perk_id]=perk
	return result

static func valid_state(data: Variant,character_level := 1000) -> bool:
	if not data is Dictionary or not data.get("masteries",{}) is Dictionary or not data.get("unlocked_perks",{}) is Dictionary: return false
	if not data.get("schema",1) is int or data.get("schema",1) not in [1,2] or not data.get("legacy_credit",0) is int or data.get("legacy_credit",0)<0 or data.get("legacy_credit",0)>180: return false
	var schools_seen: Dictionary={}; var legacy_points:=0
	for key in data.get("masteries",{}):
		if not str(key).is_valid_int() or int(key) not in TREE_RESOURCE_PATHS or not data.masteries[key] is Dictionary: return false
		if schools_seen.has(int(key)): return false
		schools_seen[int(key)]=true
		var raw: Dictionary=data.masteries[key]
		for field in ["level","perk_points"]:
			if not raw.get(field,1 if field=="level" else 0) is int: return false
		if raw.get("level",1)<1 or raw.get("level",1)>100 or raw.get("perk_points",0)<0 or raw.get("perk_points",0)>10000: return false
		for field in ["xp","xp_to_next"]:
			var value: Variant=raw.get(field,0.0 if field=="xp" else 15.0)
			if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or value<0 or value>10000000: return false
		if float(raw.get("xp_to_next",15))<=0: return false
		legacy_points+=int(raw.get("perk_points",0))
	var catalog:=definitions(); var known: Dictionary={}; var spent:=0
	schools_seen.clear()
	for key in data.get("unlocked_perks",{}):
		if not str(key).is_valid_int() or int(key) not in TREE_RESOURCE_PATHS or not data.unlocked_perks[key] is Array: return false
		if schools_seen.has(int(key)): return false
		schools_seen[int(key)]=true
		for id in data.unlocked_perks[key]:
			if not id is String or not catalog.has(id) or catalog[id].school!=int(key) or known.has(id): return false
			known[id]=true; spent+=catalog[id].cost
	for id in known:
		for required in catalog[id].prerequisite_ids:
			if not known.has(required): return false
	if data.get("schema",1)<2: return spent+legacy_points<=180
	return spent<=maxi(0,character_level-1)+int(data.get("legacy_credit",0))

static func validate_catalog() -> Array[String]:
	var errors: Array[String]=[]; var catalog: Dictionary={}
	for school in TREE_RESOURCE_PATHS:
		var tree:=load(TREE_RESOURCE_PATHS[school]) as SkillTreeData
		if not tree or tree.school!=school or tree.perks.is_empty(): errors.append("Invalid perk tree"); continue
		for raw in tree.perks:
			var perk:=raw as SkillPerkData
			if not perk or perk.perk_id.is_empty() or catalog.has(perk.perk_id) or perk.school!=school: errors.append("Invalid/duplicate perk"); continue
			catalog[perk.perk_id]=perk
			if perk.display_name.is_empty() or perk.cost<1 or perk.cost>9 or perk.required_level<1 or perk.required_level>100 or perk.required_character_level<1 or perk.required_character_level>100 or not StatsComponent.valid_requirements(perk.required_attributes) or perk.row<0 or perk.row>20 or perk.column<0 or perk.column>6: errors.append("Invalid perk requirements: "+perk.perk_id)
			if perk.grants_trigger() or perk.modifier_bonuses.is_empty(): errors.append("Perk requires an implemented, cost-respecting effect: "+perk.perk_id)
			for key in perk.modifier_bonuses:
				if key not in MODIFIER_KEYS: errors.append("Unsupported perk effect: "+str(key))
				var value: Variant=perk.modifier_bonuses[key]
				if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)): errors.append("Invalid perk modifier")
	for id in catalog: _visit_perk(id,catalog,[],errors)
	return errors

static func _visit_perk(id: String,catalog: Dictionary,path: Array[String],errors: Array[String]) -> void:
	if id in path: errors.append("Cyclic perk prerequisites: "+id); return
	var next: Array[String]=path.duplicate(); next.append(id)
	for required in catalog[id].prerequisite_ids:
		if not catalog.has(required): errors.append("Missing perk prerequisite: "+required)
		else: _visit_perk(required,catalog,next,errors)
