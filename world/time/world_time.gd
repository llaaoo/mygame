class_name WorldTime
extends Node
## 世界时间 — 24h 推进，全局单例
##
## 用法:
##   WorldTime.instance.tick(delta)
##   WorldTime.instance.get_hour()
##   WorldTime.instance.is_night()


static var instance: WorldTime

@export var time_scale: float = 60.0  ## 1 秒现实 = 60 秒游戏时间（1分钟）
var hour: float = 8.0
var _last_printed_hour: int = -1


func _ready() -> void:
	instance = self
	print("⏰ WorldTime 启动: %02d:00" % int(hour))


func _process(delta: float) -> void:
	hour += delta * time_scale / 3600.0
	if hour >= 24.0:
		hour -= 24.0
		_last_printed_hour = -1  # 跨天重置

	var current := int(hour)
	if current != _last_printed_hour:
		_last_printed_hour = current
		print("⏰ %02d:00 (%s)" % [current, "🌙 夜晚" if is_night() else "☀️ 白天"])


func get_hour() -> float:
	return hour


func is_night() -> bool:
	return hour < 6.0 or hour > 20.0
