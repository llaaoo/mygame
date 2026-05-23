class_name TriggeredEffect
extends Resource
## 触发式效果 — Event + Condition + Effect 的完整闭环
## 
## 支持两种模式：
##   1. 简单模式：conditions[] + _execute()（向后兼容）
##   2. 图模式：graph: EffectGraph（组合节点树）
## 
## 当 graph 不为 null 时，优先使用图模式

## ── 配置 ──

## 监听的事件类型
@export var trigger_type: CombatEvent.Type = CombatEvent.Type.ON_KILL

## ── 简单模式（向后兼容） ──
## 触发条件（AND 逻辑，全部满足才执行）
@export var conditions: Array[Condition] = []

## ── 图模式（优先） ──
## 效果图 — 节点组合的完整执行树
@export var graph: EffectGraph = null

## 是否启用
@export var enabled: bool = true

## 冷却（秒，0=无冷却）
@export var cooldown: float = 0.0

## ── 作用域控制（防递归爆炸） ──

## 作用域来源：skill / buff / equipment / global
@export var scope_source: String = "skill"

## 最大递归深度（0=不允许链式触发，1=允许触发1层新事件）
@export var max_recursion: int = 0

## ── 运行时（冷却状态已上交 CombatExecutor） ──


## 注册到事件总线
func register() -> void:
	CombatEventBus.subscribe_static(trigger_type, _on_event)


## 从事件总线注销
func unregister() -> void:
	if CombatEventBus.instance:
		CombatEventBus.instance.unsubscribe(trigger_type, _on_event)


## 内部回调：冷却 → 递归守卫 → 条件/图 → 执行
func _on_event(ev: CombatEvent) -> void:
	if not enabled:
		return

	# 递归守卫：_emit_depth 在进入回调前已被 emit() 置为 1
	# max_recursion=0 表示仅允许非嵌套触发，即 _emit_depth <= 1
	if CombatEventBus._emit_depth > max_recursion + 1:
		return

	# 冷却检查委托给 CombatExecutor（唯一冷却权威）
	if cooldown > 0 and CombatExecutor.instance:
		if not CombatExecutor.instance.check_trigger_cooldown(self, cooldown):
			return

	# 🆕 图模式：优先
	if graph and graph.root:
		graph.run(ev)
		return

	# 简单模式：条件 → 执行
	var ctx := _build_context(ev)
	for cond in conditions:
		if cond and not cond.check(ctx):
			return

	_execute(ev)


## 构建条件评估上下文
func _build_context(ev: CombatEvent) -> Dictionary:
	return {
		"event": ev,
		"source": ev.source,
		"target": ev.target,
		"skill": ev.skill,
		"data": ev.data,
		"depth": CombatEventBus._emit_depth,
	}


## 子类覆写：响应事件的具体逻辑（仅简单模式）
func _execute(ev: CombatEvent) -> void:
	pass
