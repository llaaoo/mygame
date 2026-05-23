class_name BuffManager
extends Node
## Buff 管理器 — 挂载到 Player 节点，管理所有激活的 Buff
##
## 装备、技能、消耗品等任何系统都通过 BuffManager 施加/移除效果

## 当前激活的所有 Buff
var _active_buffs: Array[Buff] = []

## 剩余持续时间（key=Buff实例, value=剩余秒数, duration=0=永久不在此表）
var _buff_remaining: Dictionary = {}

## tick 计时器
var _tick_timer: float = 0.0


func _process(delta: float) -> void:
	if _active_buffs.is_empty():
		return

	# Duration 倒计时
	_expire_buffs(delta)

	# Tick 计时
	_tick_timer += delta
	if _tick_timer >= 1.0:
		_tick_timer -= 1.0
		_tick_buffs()


## 倒计时并移除过期 Buff
func _expire_buffs(delta: float) -> void:
	var expired: Array[Buff] = []
	for buff in _active_buffs:
		if not _buff_remaining.has(buff):
			continue  # 永久 Buff
		var rem: float = _buff_remaining[buff] - delta
		if rem <= 0.0:
			expired.append(buff)
		else:
			_buff_remaining[buff] = rem

	for buff in expired:
		remove_buff(buff)
		_buff_remaining.erase(buff)


func _tick_buffs() -> void:
	var entity = get_parent()
	for buff in _active_buffs:
		if buff.tick_interval > 0 and buff.tick_heal > 0:
			if entity.has_method("heal"):
				entity.heal(buff.tick_heal)


## 施加 Buff（装备、技能等调用）
func apply_buff(buff: Buff) -> void:
	if not buff:
		return
	buff.apply_to(get_parent())
	_active_buffs.append(buff)

	# 有期限的 Buff 记录剩余时间
	if buff.duration > 0:
		_buff_remaining[buff] = buff.duration

	# 发射 ON_STATUS_APPLIED 事件
	CombatExecutor.report_status_applied(get_parent(), buff)

	# trace：记录 Buff 效果
	_record_buff_trace("BUFF", buff)

	print("🟢 BuffManager: 施加 %s (%.1fs)" % [buff.display_name, buff.duration])


## 移除 Buff
func remove_buff(buff: Buff) -> void:
	if not buff or not buff in _active_buffs:
		return
	buff.remove_from(get_parent())
	_active_buffs.erase(buff)
	_buff_remaining.erase(buff)

	# trace 必须在事件之前：事件处理器可能创建新 trace（如 SkillExecutor.execute）
	_record_buff_trace("BUFF_REMOVE", buff)

	# 发射 ON_STATUS_REMOVED（可能触发 TriggeredEffect → SkillExecutor → 新 trace）
	CombatExecutor.report_status_removed(get_parent(), buff)

	print("🔴 BuffManager: 移除 %s" % buff.display_name)


## trace 辅助：向活跃 trace 记录 Buff 事件
func _record_buff_trace(label: String, buff: Buff) -> void:
	var trace := CombatDebugger.active()
	if not trace:
		return
	trace.record(
		CombatTraceEvent.Category.EVENT_EMIT,
		CombatPhase.Phase.EVENT,
		"%s → %s" % [label, get_parent().name],
		"", "",
		{},
		{"effect": buff.describe()}
	)


## 检查是否拥有指定名称的 Buff（供 StatusCondition 等系统查询）
func has_buff(buff_name: String) -> bool:
	for buff in _active_buffs:
		if buff.display_name == buff_name:
			return true
	return false


## 移除所有 Buff（死亡/重置时）
func clear_all() -> void:
	for buff in _active_buffs:
		buff.remove_from(get_parent())
		CombatExecutor.report_status_removed(get_parent(), buff)
		_record_buff_trace("BUFF_REMOVE", buff)
	_active_buffs.clear()
	_buff_remaining.clear()
