class_name TargetTypeCondition
extends Condition
## 目标类型条件 — 检查目标是玩家/敌人/NPC/Boss
## 
## 示例：if target is boss → 控制效果减半

@export var target_is_player: bool = false
@export var target_is_enemy: bool = true
@export var target_is_boss: bool = false


func evaluate(ctx: Dictionary) -> bool:
	var target: Node2D = ctx.get("target", null)
	if not target:
		return false

	if target_is_player and target.is_in_group("player"):
		return true
	if target_is_enemy and target.is_in_group("enemy"):
		# Boss 判定：有 "boss" 标签
		if target_is_boss:
			return target.is_in_group("boss")
		return true

	return false
