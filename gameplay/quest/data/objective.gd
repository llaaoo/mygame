class_name QuestObjective
extends Resource
## 任务目标基类 — 监听事件，累加进度
##
## 子类覆写 on_event(ev) 定义匹配逻辑


## 需要完成的数量
@export var required_count: int = 1

## 从任务开始即追踪（true=开启宝箱类，false=击杀计数类）
## true: 阶段激活前的事件也计入进度
## false: 仅阶段激活后的事件才计数
@export var track_from_start: bool = true

## 当前进度（运行时修改）
var current: int = 0


## 事件匹配 — 子类覆写
func on_event(_ev: CombatEvent) -> bool:
	return false


## 是否完成
func is_completed() -> bool:
	return current >= required_count


## 重置进度
func reset() -> void:
	current = 0
