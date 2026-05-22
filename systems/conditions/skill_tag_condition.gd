class_name SkillTagCondition
extends Condition
## 技能标签条件 — 检查触发事件关联的技能是否有指定标签
## 
## 示例：if skill has "fire" tag → 触发火焰精通效果

@export var required_skill_tag: String = "fire"


func evaluate(ctx: Dictionary) -> bool:
	var skill: SkillData = ctx.get("skill", null)
	if not skill:
		# fallback: 从 event 中取
		var ev: CombatEvent = ctx.get("event", null)
		if ev:
			skill = ev.skill
	if not skill:
		return false
	return required_skill_tag in skill.tags
