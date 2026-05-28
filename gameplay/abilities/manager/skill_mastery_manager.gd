class_name SkillMasteryManager
extends Node
## 技能熟练度管理器 — 追踪所有技能的 XP 和等级
##
## 上古卷轴式升级循环:
##   使用技能 → 涨XP → 技能升级 → 总熟练度累加 → 人物升级

## ── 信号 ──
signal mastery_xp_gained(skill_id: String, school: int, xp_amount: float, level: int, progress: float)
signal mastery_leveled(skill_id: String, school: int, new_level: int)
signal character_leveled(new_level: int)

## ── 熟练度表 ──
var _masteries: Dictionary = {}  ## school → SkillMastery（按学派聚合）

## ── 人物等级 ──
var _character_level: int = 1
var _total_mastery_levels: int = 0
const LEVELS_PER_CHAR_LEVEL: int = 3  ## 每3个技能等级=1人物等级

## ── XP 常量 ──
const XP_DAMAGE_SCALE: float = 0.5       ## 伤害×此系数=XP
const XP_BUFF_BASE: float = 10.0          ## Buff施放基础XP
const XP_SUMMON_BASE: float = 15.0        ## 召唤基础XP
const XP_CHANNEL_TICK: float = 2.0        ## 引导每次tick XP
const XP_KILL_BONUS: float = 5.0          ## 击杀额外XP


## ── 初始化 ──

func setup() -> void:
	_ensure_mastery(SkillMastery.School.DESTRUCTION)
	_ensure_mastery(SkillMastery.School.CONJURATION)
	_ensure_mastery(SkillMastery.School.ALTERATION)
	_ensure_mastery(SkillMastery.School.ILLUSION)
	_ensure_mastery(SkillMastery.School.RESTORATION)


func _ensure_mastery(school: SkillMastery.School) -> SkillMastery:
	if _masteries.has(school):
		return _masteries[school]
	var m := SkillMastery.new()
	m.school = school
	m.skill_id = SkillMastery.School.keys()[school]
	_masteries[school] = m
	return m


## ── 公开 API ──

func get_mastery(school: SkillMastery.School) -> SkillMastery:
	return _masteries.get(school, null) as SkillMastery


func get_character_level() -> int:
	return _character_level


func get_all_masteries() -> Array[SkillMastery]:
	var result: Array[SkillMastery] = []
	for m in _masteries.values():
		result.append(m)
	return result


## ── XP 获取 ──

## 技能施放时调用
func on_skill_cast(skill: SkillData) -> void:
	if not skill:
		return
	var school := _guess_school(skill)
	var mastery := _ensure_mastery(school)

	var amount: float = XP_BUFF_BASE
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


## 造成伤害时调用
func on_deal_damage(school: SkillMastery.School, damage: int) -> void:
	var mastery: SkillMastery = _masteries.get(school) as SkillMastery
	if not mastery:
		return
	_add_xp(mastery, damage * XP_DAMAGE_SCALE)


## 引导 tick 时调用
func on_channel_tick(school: SkillMastery.School) -> void:
	var mastery: SkillMastery = _masteries.get(school) as SkillMastery
	if not mastery:
		return
	_add_xp(mastery, XP_CHANNEL_TICK)


## 击杀敌人时调用
func on_kill(school: SkillMastery.School) -> void:
	var mastery: SkillMastery = _masteries.get(school) as SkillMastery
	if not mastery:
		return
	_add_xp(mastery, XP_KILL_BONUS)


## ── 内部 ──

func _add_xp(mastery: SkillMastery, amount: float) -> void:
	if amount <= 0:
		return
	var leveled := mastery.add_xp(amount)
	var progress := mastery.get_progress()
	var school_name: String = SkillMastery.School.keys()[mastery.school]
	print("📚 [Mastery] %s +%.1f XP (Lv%d %.0f%%)" % [school_name, amount, mastery.level, progress * 100])
	mastery_xp_gained.emit(mastery.skill_id, mastery.school, amount, mastery.level, progress)
	if leveled:
		_total_mastery_levels += 1
		mastery_leveled.emit(mastery.skill_id, mastery.school, mastery.level)
		print("⭐ [Mastery] %s 升级！Lv%d" % [school_name, mastery.level])
		_check_character_level()


func _check_character_level() -> void:
	var new_level := 1 + _total_mastery_levels / LEVELS_PER_CHAR_LEVEL
	if new_level > _character_level:
		_character_level = new_level
		character_leveled.emit(_character_level)
		print("⭐ [Mastery] 人物升级！等级 %d" % _character_level)


func _guess_school(skill: SkillData) -> SkillMastery.School:
	var tags := skill.tags
	if "summon" in tags:
		return SkillMastery.School.CONJURATION
	if "ice" in tags and skill.skill_type == SkillData.SkillType.BUFF:
		return SkillMastery.School.ALTERATION
	if "shadow" in tags and skill.skill_type == SkillData.SkillType.DASH:
		return SkillMastery.School.ILLUSION
	return SkillMastery.School.DESTRUCTION
