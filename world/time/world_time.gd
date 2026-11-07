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
var elapsed_query: Callable
func bind_elapsed(query: Callable) -> void:
	elapsed_query=query
	_refresh_elapsed()
func _refresh_elapsed() -> void:
	if elapsed_query.is_valid(): hour=fposmod(8.0+float(elapsed_query.call())*time_scale/3600.0,24.0)
func day() -> int:
	return 1+int(floor((8.0*3600+float(elapsed_query.call())*time_scale)/86400.0)) if elapsed_query.is_valid() else 1
func stamp() -> String:
	var value:=get_hour()
	return "第%d天 %02d:%02d"%[day(),int(value),int(fposmod(value,1.0)*60)]


func _ready() -> void:
	# 禁用独立 _process，改为 SimulationRuntime 统一驱动
	process_mode = Node.PROCESS_MODE_DISABLED
	RuntimeRegistration.register_ticker(self)
	print("⏰ WorldTime 启动: %02d:00" % int(hour))


func _exit_tree() -> void:
	if instance == self:
		instance = null


## 统一 tick 入口（由 SimulationRuntime 驱动，替代独立 _process）
func tick(delta: float) -> void:
	if elapsed_query.is_valid(): _refresh_elapsed()
	else: hour=fposmod(hour+delta*time_scale/3600.0,24.0)
	if hour < 1.0:
		_last_printed_hour = -1  # 跨天重置

	var current := int(hour)
	if current != _last_printed_hour:
		_last_printed_hour = current
		print("⏰ %02d:00 (%s)" % [current, "🌙 夜晚" if is_night() else "☀️ 白天"])


func get_hour() -> float:
	_refresh_elapsed()
	return hour


func is_night() -> bool:
	return hour < 6.0 or hour > 20.0
