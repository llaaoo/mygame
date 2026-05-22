class_name TriggeredEffect
extends Resource
## 触发式效果 — 订阅战斗事件并作出响应
## 
## 这是"事件系统 → 行为系统"的桥梁
## 
## 用法：
##   var effect := OnKillExplosion.new()
##   effect.register()  # 自动订阅到 CombatEventBus

## ── 配置 ──

## 监听的事件类型
@export var trigger_type: CombatEvent.Type = CombatEvent.Type.ON_KILL

## 是否启用
@export var enabled: bool = true

## 冷却（秒，0=无冷却）
@export var cooldown: float = 0.0

## ── 运行时 ──
var _last_trigger_time: float = -INF


## 注册到事件总线
func register() -> void:
	CombatEventBus.subscribe_static(trigger_type, _on_event)


## 从事件总线注销
func unregister() -> void:
	CombatEventBus.instance.unsubscribe(trigger_type, _on_event)


## 内部回调（处理冷却）
func _on_event(ev: CombatEvent) -> void:
	if not enabled:
		return
	if cooldown > 0:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_trigger_time < cooldown:
			return
		_last_trigger_time = now
	_execute(ev)


## 子类覆写：响应事件的具体逻辑
func _execute(ev: CombatEvent) -> void:
	pass
