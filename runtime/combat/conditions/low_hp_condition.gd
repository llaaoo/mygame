class_name LowHPCondition
extends Condition
## 低血量条件 — 检查实体 HP 是否低于阈值
## 
## 示例：if caster.hp < 30% → 伤害+50%（绝地反击）

enum CheckTarget { SOURCE, TARGET }

@export var check_who: CheckTarget = CheckTarget.SOURCE
@export var threshold: float = 0.3               ## 阈值（0.3 = 30%）


func evaluate(ctx: Dictionary) -> bool:
	var entity: Node2D = ctx["source"] if check_who == CheckTarget.SOURCE else ctx["target"]
	if not entity:
		return false

	var health := entity.get_node_or_null("HealthComponent")
	if not health:
		return false

	return float(health.hp) / float(health.max_hp) < threshold
