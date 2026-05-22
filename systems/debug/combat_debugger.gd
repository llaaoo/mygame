class_name CombatDebugger
extends RefCounted
## 战斗调试器 — 全局追踪存储 + 查询 + 回放
## 
## 用法：
##   CombatDebugger.enabled = true          # 开启追踪
##   ... 战斗发生 ...
##   var last := CombatDebugger.get_last()  # 获取最近追踪
##   print(last.get_damage_chain())         # 查看伤害链
##   CombatDebugger.clear()                 # 清空

## ── 全局开关 ──
static var enabled: bool = false

## ── 存储 ──
static var traces: Array[CombatTrace] = []
static var _active_trace: CombatTrace = null

## 最大存储数量
const MAX_TRACES: int = 50


## 开始一次新的追踪
static func begin(chain_name: String = "", skill_name: String = "") -> CombatTrace:
	if not enabled:
		return null
	_active_trace = CombatTrace.new(chain_name)
	_active_trace.skill_name = skill_name
	return _active_trace


## 获取当前活跃追踪（SkillExecutor/CombatExecutor 用它来记录）
static func active() -> CombatTrace:
	return _active_trace if enabled else null


## 存储一次完整追踪
static func store(trace: CombatTrace) -> void:
	if not enabled or not trace:
		return
	traces.append(trace)
	if traces.size() > MAX_TRACES:
		traces.pop_front()
	_active_trace = null


## 获取最近一次追踪
static func get_last() -> CombatTrace:
	if traces.is_empty():
		return null
	return traces.back()


## 按技能名查询
static func find_by_skill(name_fragment: String) -> Array[CombatTrace]:
	var result: Array[CombatTrace] = []
	for t in traces:
		if name_fragment.to_lower() in t.skill_name.to_lower():
			result.append(t)
	return result


## 查询所有包含特定 modifier 的追踪
static func find_using_modifier(mod_name: String) -> Array[CombatTrace]:
	var result: Array[CombatTrace] = []
	for t in traces:
		for ev in t.events:
			if ev.category == CombatTraceEvent.Category.MODIFIER_APPLY and mod_name in ev.source:
				result.append(t)
				break
	return result


## ── 回放 ──

## 逐步回放：返回某一步的事件（1-based）
static func replay_step(trace: CombatTrace, step: int) -> CombatTraceEvent:
	if not trace or step < 1 or step > trace.events.size():
		return null
	return trace.events[step - 1]


## 获取追踪摘要
static func summarize(trace: CombatTrace) -> String:
	if not trace:
		return "(null)"
	var lines: Array[String] = []
	lines.append("═══ CombatTrace: %s ═══" % trace.chain_id)
	lines.append("  Skill: %s | Events: %d | Damage: %d" % [trace.skill_name, trace.events.size(), trace.final_damage])
	lines.append("  Damage Chain: %s" % trace.get_damage_chain())

	var i := 1
	for ev in trace.events:
		var prefix := "  %2d." % i
		match ev.category:
			CombatTraceEvent.Category.FIREWALL_BLOCK:
				lines.append("%s 🚫 %s" % [prefix, ev.event_name])
			CombatTraceEvent.Category.MODIFIER_APPLY:
				var delta: int = ev.metadata.get("delta", 0)
				lines.append("%s 📊 %s: %d → %d (%+d)" % [prefix, ev.event_name, ev.input_data.get("damage", 0), ev.output_data.get("damage", 0), delta])
			CombatTraceEvent.Category.CONDITION_CHECK:
				var r: bool = ev.output_data.get("result", false)
				lines.append("%s 🔍 %s: %s" % [prefix, ev.event_name, "✅" if r else "❌"])
			CombatTraceEvent.Category.EVENT_EMIT:
				lines.append("%s 📡 %s → %s" % [prefix, ev.event_name, ev.target])
			_:
				lines.append("%s · %s" % [prefix, ev.event_name])
		i += 1

	return "\n".join(lines)


## 清空所有追踪
static func clear() -> void:
	traces.clear()
	_active_trace = null


## 获取追踪数量
static func count() -> int:
	return traces.size()
