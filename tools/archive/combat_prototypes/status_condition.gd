class_name StatusCondition
extends Condition
## 状态条件 — 检查实体是否拥有某个 Buff/Status
## 
## 示例：if target.has_status("burning") → 火球伤害+50%

enum CheckTarget { SOURCE, TARGET }

@export var check_who: CheckTarget = CheckTarget.TARGET
@export var status_id: String = "burning"         ## Buff.display_name 或自定义 id


func evaluate(ctx: Dictionary) -> bool:
	var entity: Node2D = ctx["source"] if check_who == CheckTarget.SOURCE else ctx["target"]
	if not entity:
		return false

	var buff_manager := entity.get_node_or_null("BuffManager")
	if not buff_manager:
		return false

	return buff_manager.has_buff(status_id)
