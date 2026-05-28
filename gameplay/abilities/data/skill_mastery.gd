class_name SkillMastery
extends Resource
## 技能熟练度 — 跟踪单个技能的 XP 和等级
##
## 上古卷轴式：使用技能 → 涨该技能XP → 技能升级 → 总等级提升

## ── 学派枚举 ──
enum School {
	DESTRUCTION,   ## 毁灭系：火球、烈焰风暴、冰风暴、闪电弹、毒云
	CONJURATION,   ## 召唤系：召唤骷髅
	RESTORATION,   ## 恢复系：(未来治疗)
	ALTERATION,    ## 变化系：冰霜护盾
	ILLUSION,      ## 幻术系：暗影步
}

## ── 数据 ──
@export var skill_id: String = ""
@export var school: School = School.DESTRUCTION
@export var level: int = 1
@export var xp: float = 0.0
@export var xp_to_next: float = 15.0


## 添加 XP，返回是否升级
func add_xp(amount: float) -> bool:
	xp += amount
	if xp >= xp_to_next and level < 100:
		return _level_up()
	return false


func _level_up() -> bool:
	xp -= xp_to_next
	level += 1
	xp_to_next = _calc_xp_for_level(level)
	# 可能连续升级
	if xp >= xp_to_next and level < 100:
		_level_up()
	return true


static func _calc_xp_for_level(lvl: int) -> float:
	return lvl * lvl * 0.8 + lvl * 3.0 + 10.0


func get_progress() -> float:
	return xp / xp_to_next


func get_school_name() -> String:
	return School.keys()[school]
