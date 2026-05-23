class_name TagCondition
extends Condition
## 标签匹配条件 — 检查实体（source 或 target）是否拥有指定标签
## 
## ctx 约定: {"event": CombatEvent, "source": Node2D, "target": Node2D, "skill": SkillData}

## 检查谁
enum CheckTarget { SOURCE, TARGET }

@export var check_who: CheckTarget = CheckTarget.TARGET
@export var required_tag: String = ""


func evaluate(ctx: Dictionary) -> bool:
	var entity: Node2D = ctx["source"] if check_who == CheckTarget.SOURCE else ctx["target"]
	if not entity:
		return false
	return entity.is_in_group(required_tag)
