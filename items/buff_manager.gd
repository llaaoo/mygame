class_name BuffManager
extends Node
## Buff 管理器 — 挂载到 Player 节点，管理所有激活的 Buff
##
## 装备、技能、消耗品等任何系统都通过 BuffManager 施加/移除效果

## 当前激活的所有 Buff
var _active_buffs: Array[Buff] = []

## 剩余持续时间（key=Buff实例, value=剩余秒数, duration=0=永久不在此表）
var _buff_remaining: Dictionary = {}

## 叠加层数（key=Buff实例, value=当前层数, 仅 stack_behavior=INTENSITY）
var _stacks: Dictionary = {}

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
		if buff.tick_interval <= 0:
			continue
		
		var stacks: int = _stacks.get(buff, 1)
		
		# DOT 伤害
		if buff.tick_damage > 0:
			var dmg: int = buff.tick_damage * stacks
			if buff.tick_damage_scaling > 0.0:
				var stats := entity.get_node_or_null("StatsComponent")
				if stats and "magic_damage" in stats:
					dmg += int(stats.magic_damage * buff.tick_damage_scaling)
			if entity.has_method("take_damage"):
				entity.take_damage(dmg)
		
		# HOT 治疗
		if buff.tick_heal > 0 and entity.has_method("heal"):
			entity.heal(buff.tick_heal * stacks)


## 施加 Buff（装备、技能等调用）
func apply_buff(buff: Buff) -> void:
	if not buff:
		return
	
	# 叠加逻辑
	match buff.stack_behavior:
		Buff.StackBehavior.REFRESH:
			# 找同 status_id 的已有 Buff，刷新持续时间
			if not buff.status_id.is_empty():
				var existing := _find_by_status(buff.status_id)
				if existing:
					remove_buff(existing)
		Buff.StackBehavior.INTENSITY:
			if not buff.status_id.is_empty():
				var existing := _find_by_status(buff.status_id)
				if existing:
					var cur: int = _stacks.get(existing, 1)
					if cur < existing.max_stacks:
						_stacks[existing] = cur + 1
						_buff_remaining[existing] = existing.duration
						print("🟡 BuffManager: %s 层数 %d→%d" % [existing.display_name, cur, cur + 1])
						return
					return  # 满层不叠加
		Buff.StackBehavior.INDEPENDENT:
			pass  # 允许同 status_id 多个实例
	
	# 标准施加
	buff.apply_to(get_parent())
	_active_buffs.append(buff)
	
	if buff.stack_behavior == Buff.StackBehavior.INTENSITY:
		_stacks[buff] = 1
	
	if buff.duration > 0:
		_buff_remaining[buff] = buff.duration
	
	CombatExecutor.report_status_applied(get_parent(), buff)
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
		if buff.display_name == buff_name or buff.status_id == buff_name:
			return true
	return false


## 获取所有活跃状态 ID（供 AI / Surface 系统查询）
func get_active_statuses() -> Array[String]:
	var result: Array[String] = []
	for buff in _active_buffs:
		if not buff.status_id.is_empty():
			result.append(buff.status_id)
	return result


## 获取指定状态的当前层数
func get_stack_count(status_id_str: String) -> int:
	var buff := _find_by_status(status_id_str)
	return _stacks.get(buff, 0)


## 内部：按 status_id 查找已有的 Buff 实例
func _find_by_status(sid: String) -> Buff:
	for buff in _active_buffs:
		if buff.status_id == sid:
			return buff
	return null


## 移除所有 Buff（死亡/重置时）
func clear_all() -> void:
	for buff in _active_buffs:
		buff.remove_from(get_parent())
		CombatExecutor.report_status_removed(get_parent(), buff)
		_record_buff_trace("BUFF_REMOVE", buff)
	_active_buffs.clear()
	_buff_remaining.clear()
	_stacks.clear()
