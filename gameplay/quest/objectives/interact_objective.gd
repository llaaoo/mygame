class_name InteractObjective
extends QuestObjective
## 交互目标 — 匹配 ON_INTERACT 事件 + 可选标签过滤


## 目标标签（空 = 任意交互物体）
@export var target_tag: String = ""


func on_event(ev: CombatEvent) -> bool:
	if ev.type != CombatEvent.Type.ON_INTERACT:
		return false
	if not target_tag.is_empty():
		if not ev.target.is_in_group(target_tag):
			return false
	current += 1
	return true
