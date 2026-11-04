class_name CombatEventBus
extends Node
## 战斗事件总线 — 全局发布/订阅
##
## 用法：
##   发射方: CombatEventBus.emit(CombatEvent.create(ON_HIT, caster, target))
##   订阅方: CombatEventBus.subscribe(CombatEvent.Type.ON_KILL, func(ev): ...)
##
## 原则：
##   - 单例：每个场景一个实例，通过 static instance 访问
##   - 订阅者不修改事件（事件是已发生的事实）
##   - 回调中抛异常不会中断其他订阅者

## ── 全局静态访问 ──
static var instance: CombatEventBus = null

## 当前事件发射深度（防递归爆炸，TriggeredEffect.max_recursion 引用）
static var _emit_depth: int = 0

## 硬上限（不可绕过）
const MAX_DEPTH_HARD: int = 5


## ── 订阅表 ──
## key = CombatEvent.Type (int), value = Array[Callable]
var _listeners: Dictionary = {}
var _once_callbacks: Dictionary = {}
var _subscription_serial := 0


func _ready() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


## ── 订阅 ──

func subscribe(event_type: CombatEvent.Type, callback: Callable) -> void:
	if not _listeners.has(event_type):
		_listeners[event_type] = []
	var arr: Array = _listeners[event_type]
	if callback not in arr:
		arr.append(callback)


func unsubscribe(event_type: CombatEvent.Type, callback: Callable) -> void:
	if not _listeners.has(event_type):
		return
	var arr: Array = _listeners[event_type]
	arr.erase(callback)


## 一次性订阅（触发后自动移除）
func once(event_type: CombatEvent.Type, callback: Callable) -> void:
	_subscription_serial += 1
	var wrapper := _dispatch_once.bind(_subscription_serial)
	_once_callbacks[_subscription_serial] = {"type": event_type, "callback": callback, "wrapper": wrapper}
	subscribe(event_type, wrapper)

func _dispatch_once(event: CombatEvent, id: int) -> void:
	var entry: Dictionary = _once_callbacks.get(id, {})
	if entry.is_empty():
		return
	_once_callbacks.erase(id)
	unsubscribe(entry.type, entry.wrapper)
	if entry.callback.is_valid():
		entry.callback.call(event)


## ── 发射 ──

func emit(ev: CombatEvent) -> void:
	if not _listeners.has(ev.type):
		return

	# 硬上限防火墙
	if _emit_depth >= MAX_DEPTH_HARD:
		push_warning("[CombatEventBus] emit blocked: max depth %d reached" % MAX_DEPTH_HARD)
		return

	# 递归深度 +1
	_emit_depth += 1

	# 复制列表，防止回调中修改订阅表
	var arr: Array = _listeners[ev.type].duplicate()
	var pruned := false
	for cb in arr:
		# 容错：跳过已释放的回调
		if not (cb as Callable).is_valid():
			pruned = true
			continue
		cb.call(ev)

	# 清理无效回调
	if pruned:
		var clean: Array = []
		for cb in _listeners[ev.type]:
			if (cb as Callable).is_valid():
				clean.append(cb)
		_listeners[ev.type] = clean

	# 递归深度 -1
	_emit_depth -= 1


## ── 静态快捷方法 ──

static func subscribe_static(event_type: CombatEvent.Type, callback: Callable) -> void:
	if instance:
		instance.subscribe(event_type, callback)


static func emit_static(ev: CombatEvent) -> void:
	if instance:
		instance.emit(ev)


static func once_static(event_type: CombatEvent.Type, callback: Callable) -> void:
	if instance:
		instance.once(event_type, callback)


## ── 工具 ──

func clear_all() -> void:
	_listeners.clear()
	_once_callbacks.clear()


func get_listener_count(event_type: CombatEvent.Type = -1) -> int:
	if event_type == -1:
		var total := 0
		for arr in _listeners.values():
			total += (arr as Array).size()
		return total
	if not _listeners.has(event_type):
		return 0
	return (_listeners[event_type] as Array).size()
