class_name SkillMasteryManager
extends Node

signal mastery_xp_gained(skill_id: String, school: int, xp_amount: float, level: int, progress: float)
signal mastery_leveled(skill_id: String, school: int, new_level: int)
signal character_leveled(new_level: int)
signal perk_points_changed(school: int, points: int)
signal perk_unlocked(school: int, perk_id: String)

const LEVELS_PER_CHAR_LEVEL: int = 3
const XP_DAMAGE_SCALE: float = 0.5
const XP_BUFF_BASE: float = 10.0
const XP_SUMMON_BASE: float = 15.0
const XP_CHANNEL_TICK: float = 2.0
const XP_KILL_BONUS: float = 5.0
const ICE_ARMOR_NAME := "ice_armor"
const TREE_RESOURCE_PATHS := {
	SkillMastery.School.DESTRUCTION: "res://gameplay/abilities/data/trees/destruction_tree.tres",
	SkillMastery.School.CONJURATION: "res://gameplay/abilities/data/trees/conjuration_tree.tres",
	SkillMastery.School.RESTORATION: "res://gameplay/abilities/data/trees/restoration_tree.tres",
	SkillMastery.School.ALTERATION: "res://gameplay/abilities/data/trees/alteration_tree.tres",
	SkillMastery.School.ILLUSION: "res://gameplay/abilities/data/trees/illusion_tree.tres",
}

var _masteries: Dictionary = {}
var _trees: Dictionary = {}
var _unlocked_perks: Dictionary = {}
var _character_level: int = 1
var _total_mastery_levels: int = 0
var _owner_entity: Node = null


func setup(owner: Node = null) -> void:
	_owner_entity = owner
	for school in [
		SkillMastery.School.DESTRUCTION,
		SkillMastery.School.CONJURATION,
		SkillMastery.School.ALTERATION,
		SkillMastery.School.ILLUSION,
		SkillMastery.School.RESTORATION,
	]:
		_ensure_mastery(school)
		_trees[school] = _load_tree_for_school(school)
		_unlocked_perks[school] = []
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
	return _character_level


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


func get_unlocked_perks_for_school(school: SkillMastery.School) -> Array[String]:
	var result: Array[String] = []
	for perk_id in _unlocked_perks.get(school, []):
		result.append(str(perk_id))
	return result


func get_available_perk_points(school: SkillMastery.School) -> int:
	var mastery := get_mastery(school)
	return mastery.perk_points if mastery else 0


func has_perk(perk_id: String) -> bool:
	for school in _unlocked_perks.keys():
		var unlocked: Array = _unlocked_perks[school]
		if perk_id in unlocked:
			return true
	return false


func get_perk(perk_id: String) -> SkillPerkData:
	return _find_perk(perk_id)


func unlock_perk(perk_id: String) -> bool:
	var perk := _find_perk(perk_id)
	if not perk:
		return false
	if has_perk(perk_id):
		return false

	var mastery := get_mastery(perk.school)
	if not mastery or mastery.level < perk.required_level:
		return false
	if mastery.perk_points < perk.cost:
		return false
	for req: String in perk.prerequisite_ids:
		if not has_perk(req):
			return false

	mastery.perk_points -= perk.cost
	var unlocked: Array = _unlocked_perks.get(perk.school, [])
	unlocked.append(perk.perk_id)
	_unlocked_perks[perk.school] = unlocked
	perk_points_changed.emit(perk.school, mastery.perk_points)
	perk_unlocked.emit(perk.school, perk.perk_id)
	return true


func can_unlock_perk(perk_id: String) -> bool:
	var perk := _find_perk(perk_id)
	if not perk or has_perk(perk_id):
		return false
	var mastery := get_mastery(perk.school)
	if not mastery or mastery.level < perk.required_level or mastery.perk_points < perk.cost:
		return false
	for req: String in perk.prerequisite_ids:
		if not has_perk(req):
			return false
	return true


func get_modifier_value(key: String, default_value: float = 0.0) -> float:
	var value := default_value
	for school in _trees.keys():
		for perk in _trees[school]:
			if has_perk(perk.perk_id):
				value += float(perk.modifier_bonuses.get(key, 0.0))
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
		"character_level": _character_level,
		"total_mastery_levels": _total_mastery_levels,
		"masteries": masteries,
		"unlocked_perks": unlocked,
	}


func restore_state(data: Dictionary) -> void:
	for school_key in data.get("masteries", {}).keys():
		var school := int(school_key)
		var mastery := _ensure_mastery(school)
		var raw: Dictionary = data["masteries"][school_key]
		mastery.level = raw.get("level", mastery.level)
		mastery.xp = raw.get("xp", mastery.xp)
		mastery.xp_to_next = raw.get("xp_to_next", mastery.xp_to_next)
		mastery.perk_points = raw.get("perk_points", mastery.perk_points)

	for school_key in data.get("unlocked_perks", {}).keys():
		var school := int(school_key)
		var perk_ids: Array[String] = []
		for perk_id in data["unlocked_perks"][school_key]:
			perk_ids.append(str(perk_id))
		_unlocked_perks[school] = perk_ids

	_recompute_totals()


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
	if amount <= 0:
		return
	var previous_points := mastery.perk_points
	var leveled := mastery.add_xp(amount)
	var progress := mastery.get_progress()
	mastery_xp_gained.emit(mastery.skill_id, mastery.school, amount, mastery.level, progress)
	if leveled:
		mastery_leveled.emit(mastery.skill_id, mastery.school, mastery.level)
		if mastery.perk_points != previous_points:
			perk_points_changed.emit(mastery.school, mastery.perk_points)
		_recompute_totals()


func _recompute_totals() -> void:
	_total_mastery_levels = 0
	for mastery in _masteries.values():
		_total_mastery_levels += max(0, mastery.level - 1)
	var new_level := 1 + _total_mastery_levels / LEVELS_PER_CHAR_LEVEL
	if new_level > _character_level:
		_character_level = new_level
		character_leveled.emit(_character_level)
	else:
		_character_level = new_level


func _guess_school(skill: SkillData) -> SkillMastery.School:
	var tags := skill.tags
	if "summon" in tags:
		return SkillMastery.School.CONJURATION
	if "ice" in tags and skill.skill_type == SkillData.SkillType.BUFF:
		return SkillMastery.School.ALTERATION
	if "shadow" in tags and skill.skill_type == SkillData.SkillType.DASH:
		return SkillMastery.School.ILLUSION
	if "heal" in tags or "holy" in tags:
		return SkillMastery.School.RESTORATION
	return SkillMastery.School.DESTRUCTION


func _find_perk(perk_id: String) -> SkillPerkData:
	for school in _trees.keys():
		for perk in _trees[school]:
			if perk.perk_id == perk_id:
				return perk
	return null


func _load_tree_for_school(school: SkillMastery.School) -> Array[SkillPerkData]:
	var path: String = TREE_RESOURCE_PATHS.get(school, "")
	if not path.is_empty():
		var tree_resource: Resource = load(path)
		if tree_resource and "perks" in tree_resource:
			var perks: Array[SkillPerkData] = []
			for perk in tree_resource.get("perks"):
				var perk_resource := perk as SkillPerkData
				if perk_resource:
					perks.append(perk_resource)
			return perks
	return _build_default_tree(school)


func _build_default_tree(school: SkillMastery.School) -> Array[SkillPerkData]:
	match school:
		SkillMastery.School.DESTRUCTION:
			return [
				_make_perk("destruction_scorch", school, "余烬加深", "火焰系伤害提升 15%。", 5, {"damage.fire": 0.15}),
				_make_trigger_perk("destruction_firestorm", school, "焚灭余烬", "火焰击杀后自动引爆烈焰风暴。", 10, "flame_storm", CombatEvent.Type.ON_KILL, "fire", "", ["destruction_scorch"]),
				_make_perk("destruction_storm_web", school, "雷网", "闪电链额外弹射 2 次。", 20, {"chain.lightning_bounces": 2.0}, ["destruction_firestorm"]),
				_make_perk("destruction_deepfreeze", school, "霜蚀", "冰系伤害提升 12%，冻结持续时间提升 50%。", 30, {"damage.ice": 0.12, "status.frozen_duration": 0.5}, ["destruction_storm_web"]),
			]
		SkillMastery.School.CONJURATION:
			return [
				_make_perk("conjuration_extra_slot", school, "并行契约", "召唤上限 +1。", 5, {"summon.max_count": 1.0}),
				_make_perk("conjuration_iron_pact", school, "铁誓", "召唤物生命提升 25%。", 10, {"summon.hp_multiplier": 0.25}, ["conjuration_extra_slot"]),
				_make_perk("conjuration_battle_drum", school, "战鼓", "召唤物伤害提升 25%。", 20, {"summon.damage_multiplier": 0.25}, ["conjuration_iron_pact"]),
				_make_perk("conjuration_long_service", school, "长役", "召唤持续时间提升 50%。", 30, {"summon.duration_multiplier": 0.5}, ["conjuration_battle_drum"]),
			]
		SkillMastery.School.RESTORATION:
			return [
				_make_perk("restoration_stability", school, "稳态", "所有增益持续时间提升 20%。", 5, {"buff.duration.all": 0.2}),
				_make_perk("restoration_mending", school, "复原", "恢复类技能冷却缩短 10%。", 10, {"cooldown.heal": -0.1}, ["restoration_stability"]),
				_make_perk("restoration_cleanse", school, "净化", "燃烧与中毒的持续时间缩短 35%。", 20, {"status.burning_duration": -0.35, "status.poison_duration": -0.35}, ["restoration_mending"]),
				_make_perk("restoration_reserve", school, "储备", "全局法术伤害与治疗效率提升 8%。", 30, {"damage.all": 0.08}, ["restoration_cleanse"]),
			]
		SkillMastery.School.ALTERATION:
			return [
				_make_perk("alteration_guarded_skin", school, "护体织层", "冰甲持续时间提升 50%。", 5, {"buff.ice_armor.duration": 0.5}),
				_make_trigger_perk("alteration_shatter", school, "碎冰回响", "冰霜护盾结束时自动释放冰爆。", 10, "ice_explosion", CombatEvent.Type.ON_STATUS_REMOVED, "", ICE_ARMOR_NAME, ["alteration_guarded_skin"]),
				_make_perk("alteration_stone_stride", school, "石肤步伐", "位移类技能冷却缩短 15%。", 20, {"cooldown.shadow_step": -0.15}, ["alteration_shatter"]),
				_make_perk("alteration_frozen_edge", school, "凝锋", "冻结目标受到的冰系伤害额外提升 15%。", 30, {"damage.ice": 0.15}, ["alteration_stone_stride"]),
			]
		SkillMastery.School.ILLUSION:
			return [
				_make_perk("illusion_slipstream", school, "影流", "位移类技能冷却缩短 12%。", 5, {"cooldown.shadow_step": -0.12}),
				_make_perk("illusion_predator", school, "捕猎者", "暗影技能伤害提升 18%。", 10, {"damage.shadow": 0.18}, ["illusion_slipstream"]),
				_make_perk("illusion_misdirect", school, "误导", "敌人脱战前会更久地搜索你。", 20, {"status.illusion_pressure": 1.0}, ["illusion_predator"]),
				_make_perk("illusion_afterimage", school, "残像", "闪避后下一次暗影技能额外提升 20% 伤害。", 30, {"damage.shadow": 0.2}, ["illusion_misdirect"]),
			]
	return []


func _make_perk(
	perk_id: String,
	school: SkillMastery.School,
	display_name: String,
	description: String,
	required_level: int,
	modifiers: Dictionary,
	prerequisites: Array[String] = []
) -> SkillPerkData:
	var perk := SkillPerkData.new()
	perk.perk_id = perk_id
	perk.school = school
	perk.display_name = display_name
	perk.description = description
	perk.required_level = required_level
	perk.modifier_bonuses = modifiers
	perk.prerequisite_ids = prerequisites
	return perk


func _make_trigger_perk(
	perk_id: String,
	school: SkillMastery.School,
	display_name: String,
	description: String,
	required_level: int,
	skill_id: String,
	event_type: CombatEvent.Type,
	required_tag: String,
	required_buff_name: String,
	prerequisites: Array[String] = []
) -> SkillPerkData:
	var perk := _make_perk(perk_id, school, display_name, description, required_level, {}, prerequisites)
	perk.trigger_skill_id = skill_id
	perk.trigger_event = event_type
	perk.trigger_required_tag = required_tag
	perk.trigger_required_buff_name = required_buff_name
	return perk
