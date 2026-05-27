class_name SkillTagCondition
extends Condition
## 技能标签条件 — 检查触发事件关联的技能是否有指定标签
## 
## 示例：if skill has "fire" tag → 触发火焰精通效果

@export var required_skill_tag: String = "fire"


func evaluate(ctx: Dictionary) -> bool:
	var skill: SkillData = ctx.get("skill", null)
	if not skill:
		var ev: CombatEvent = ctx.get("event", null)
		if ev:
			skill = ev.skill
	if skill and required_skill_tag in skill.tags:
		return true
	# fallback: ON_KILL 等无 skill 的事件，检查 ev.data.tags
	var ev: CombatEvent = ctx.get("event", null)
	if ev:
		var tags: Array = ev.data.get("tags", [])
		if required_skill_tag in tags:
			return true
	return false
