class_name ScheduleEntry
extends Resource
## 日程条目 — 指定时间段执行什么 Task


@export var start_hour: int = 8
@export var end_hour: int = 18

## 目标 marker ID
@export var target_marker: String = ""

## 动作类型: "move" / "idle" / "wander"
@export var action_type: String = "move"
