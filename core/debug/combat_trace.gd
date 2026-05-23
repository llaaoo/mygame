class_name CombatTrace
extends RefCounted
## 战斗追踪链 — 一次完整战斗链的所有事件
## 
## 生命周期：
##   trace = CombatTrace.new("fireball_cast")
##   trace.record_phase_enter(...)
##   trace.record_modifier(...)
##   trace.record_event(...)
##   CombatDebugger.store(trace)

## 链标识
var chain_id: String = ""
var skill_name: String = ""
var started_at_ms: int = 0

## 事件列表
var events: Array[CombatTraceEvent] = []

## 总伤害（快速查询）
var final_damage: int = 0

## 是否已存储（防重复输出）
var _stored: bool = false


func _init(chain_name: String = "") -> void:
	chain_id = chain_name
	started_at_ms = Time.get_ticks_msec()


## ── 记录快捷方法 ──

func record(cat: CombatTraceEvent.Category, phase: CombatPhase.Phase, name_str: String, src: String = "", tgt: String = "", input: Dictionary = {}, output: Dictionary = {}, meta: Dictionary = {}) -> void:
	var ev := CombatTraceEvent.create(cat, phase, name_str)
	ev.source = src
	ev.target = tgt
	ev.input_data = input
	ev.output_data = output
	ev.metadata = meta
	ev.depth = CombatEventBus._emit_depth
	events.append(ev)


func record_modifier(mod_name: String, stage_name: String, before: int, after: int, tags: Array = []) -> void:
	record(
		CombatTraceEvent.Category.MODIFIER_APPLY,
		CombatPhase.Phase.MODIFIER,
		"%s @ %s" % [mod_name, stage_name],
		mod_name, "",
		{"damage": before},
		{"damage": after},
		{"tags": tags, "delta": after - before}
	)


func record_condition(cond_name: String, result: bool, why: String = "") -> void:
	record(
		CombatTraceEvent.Category.CONDITION_CHECK,
		CombatPhase.Phase.CONDITION,
		cond_name,
		cond_name, "",
		{},
		{"result": result},
		{"why": why}
	)


func record_event(ev_type: String, src: String, tgt: String, data: Dictionary) -> void:
	record(
		CombatTraceEvent.Category.EVENT_EMIT,
		CombatPhase.Phase.EVENT,
		ev_type, src, tgt,
		{}, data
	)


func record_firewall(reason: String) -> void:
	record(
		CombatTraceEvent.Category.FIREWALL_BLOCK,
		CombatPhase.Phase.EVENT,
		"BLOCKED: " + reason,
		"CombatExecutor", "", {}, {}
	)


## ── 查询 ──

func find_by_category(cat: CombatTraceEvent.Category) -> Array[CombatTraceEvent]:
	var result: Array[CombatTraceEvent] = []
	for ev in events:
		if ev.category == cat:
			result.append(ev)
	return result


func get_damage_chain() -> String:
	var parts: Array[String] = []
	for ev in find_by_category(CombatTraceEvent.Category.MODIFIER_APPLY):
		var delta: int = ev.metadata.get("delta", 0)
		var sign := "+" if delta >= 0 else ""
		parts.append("%s(%s%d)" % [ev.source, sign, delta])
	return " → ".join(parts) if not parts.is_empty() else "(no modifiers)"
