class_name BuffNameCondition
extends Condition
## Buff 名称条件 — 检查事件的 buff_name 是否匹配
## 
## 用于 ON_STATUS_APPLIED / ON_STATUS_REMOVED 事件的过滤
## 示例：required_buff_name = "冰霜护盾" → 只在冰甲事件时通过

@export var required_buff_name: String = ""


func evaluate(ctx: Dictionary) -> bool:
	var ev: CombatEvent = ctx.get("event", null)
	if not ev:
		return false
	return ev.data.get("buff_name", "") == required_buff_name or ev.data.get("status_id", "") == required_buff_name
