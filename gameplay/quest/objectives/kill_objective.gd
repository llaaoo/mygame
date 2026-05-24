class_name KillObjective
extends QuestObjective
## 击杀目标 — 匹配 ON_KILL 事件 + 可选标签过滤


## 目标标签（空 = 任意敌人）
@export var target_tag: String = "enemy"


func on_event(ev: CombatEvent) -> bool:
	if ev.type != CombatEvent.Type.ON_KILL:
		return false
	if not target_tag.is_empty():
		if not ev.target.is_in_group(target_tag):
			return false
	current += 1
	return true
