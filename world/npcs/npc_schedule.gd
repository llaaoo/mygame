class_name NPCSchedule
extends Resource
## NPC 日程 — 按时间段切换行为


@export var entries: Array[ScheduleEntry] = []


## 根据当前时间返回应执行的条目
func get_entry_for_hour(hour: float) -> ScheduleEntry:
	for entry in entries:
		if entry.start_hour <= entry.end_hour:
			if hour >= entry.start_hour and hour < entry.end_hour:
				return entry
		else:  # 跨午夜 (如 22:00-06:00)
			if hour >= entry.start_hour or hour < entry.end_hour:
				return entry
	return null
