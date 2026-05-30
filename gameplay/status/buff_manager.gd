class_name BuffManager
extends Node

signal buffs_changed

var _active_buffs: Array[Buff] = []
var _buff_remaining: Dictionary = {}
var _stacks: Dictionary = {}
var _tick_elapsed: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	_register_with_simulation()


func _register_with_simulation() -> void:
	var gr := GameRuntime.instance
	if not gr:
		call_deferred("_register_with_simulation")
		return
	var sim := gr.get_simulation_runtime()
	if not sim:
		call_deferred("_register_with_simulation")
		return
	sim.register_ticker(self)


func tick(delta: float) -> void:
	if _active_buffs.is_empty():
		return
	_expire_buffs(delta)
	_tick_buffs(delta)


func apply_buff(buff: Buff) -> void:
	if not buff:
		return

	if not buff.exclusive_group.is_empty():
		_remove_by_exclusive_group(buff.exclusive_group)

	match buff.stack_behavior:
		Buff.StackBehavior.REFRESH:
			var existing := _find_matching_buff(buff)
			if existing:
				_refresh_buff(existing, buff.duration)
				return
		Buff.StackBehavior.INTENSITY:
			var stacked := _find_matching_buff(buff)
			if stacked:
				var current: int = int(_stacks.get(stacked, 1))
				if current < stacked.max_stacks:
					_stacks[stacked] = current + 1
				_refresh_buff(stacked, stacked.duration)
				buffs_changed.emit()
				return
		Buff.StackBehavior.INDEPENDENT:
			pass

	buff.apply_to(get_parent())
	_active_buffs.append(buff)
	_stacks[buff] = 1
	if buff.duration > 0.0:
		_buff_remaining[buff] = buff.duration
	if buff.tick_interval > 0.0:
		_tick_elapsed[buff] = 0.0
	CombatExecutor.report_status_applied(get_parent(), buff)
	_record_buff_trace("BUFF", buff)
	buffs_changed.emit()


func remove_buff(buff: Buff) -> void:
	if not buff or buff not in _active_buffs:
		return
	buff.remove_from(get_parent())
	_active_buffs.erase(buff)
	_buff_remaining.erase(buff)
	_stacks.erase(buff)
	_tick_elapsed.erase(buff)
	_record_buff_trace("BUFF_REMOVE", buff)
	CombatExecutor.report_status_removed(get_parent(), buff)
	buffs_changed.emit()


func has_buff(buff_name: String) -> bool:
	for buff in _active_buffs:
		if buff.display_name == buff_name or buff.status_id == buff_name or buff.get_runtime_id() == buff_name:
			return true
	return false


func get_active_statuses() -> Array[String]:
	var result: Array[String] = []
	for buff in _active_buffs:
		if not buff.status_id.is_empty():
			result.append(buff.status_id)
	return result


func get_stack_count(status_id_str: String) -> int:
	var buff := _find_by_status(status_id_str)
	return _stacks.get(buff, 0)


func get_active_buff_entries() -> Array:
	var result: Array = []
	for active_buff in _active_buffs:
		var remaining: float = _buff_remaining.get(active_buff, 0.0)
		var duration := maxf(active_buff.duration, 0.0)
		var progress := 1.0
		if duration > 0.0:
			progress = clampf(remaining / duration, 0.0, 1.0)
		result.append({
			"id": active_buff.get_runtime_id(),
			"name": active_buff.display_name if not active_buff.display_name.is_empty() else active_buff.status_id,
			"status_id": active_buff.status_id,
			"icon": active_buff.icon,
			"remaining": remaining,
			"duration": duration,
			"progress": progress,
			"stacks": _stacks.get(active_buff, 1),
			"description": active_buff.describe(),
			"resource_path": active_buff.resource_path,
		})
	return result


func serialize_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for buff in _active_buffs:
		result.append({
			"resource_path": buff.resource_path,
			"runtime_id": buff.get_runtime_id(),
			"remaining": _buff_remaining.get(buff, buff.duration),
			"stacks": _stacks.get(buff, 1),
			"tick_elapsed": _tick_elapsed.get(buff, 0.0),
		})
	return result


func restore_state(entries: Array[Dictionary]) -> void:
	clear_all()
	for entry in entries:
		var path := str(entry.get("resource_path", ""))
		if path.is_empty():
			continue
		var buff := load(path) as Buff
		if not buff:
			continue
		var runtime_buff := buff.duplicate(true) as Buff
		apply_buff(runtime_buff)
		if runtime_buff.duration > 0.0:
			_buff_remaining[runtime_buff] = float(entry.get("remaining", runtime_buff.duration))
		_stacks[runtime_buff] = int(entry.get("stacks", 1))
		if runtime_buff.tick_interval > 0.0:
			_tick_elapsed[runtime_buff] = float(entry.get("tick_elapsed", 0.0))


func clear_all() -> void:
	for buff in _active_buffs:
		buff.remove_from(get_parent())
		CombatExecutor.report_status_removed(get_parent(), buff)
		_record_buff_trace("BUFF_REMOVE", buff)
	_active_buffs.clear()
	_buff_remaining.clear()
	_stacks.clear()
	_tick_elapsed.clear()
	buffs_changed.emit()


func _expire_buffs(delta: float) -> void:
	var expired: Array[Buff] = []
	for buff in _active_buffs:
		if not _buff_remaining.has(buff):
			continue
		var remaining: float = _buff_remaining[buff] - delta
		if remaining <= 0.0:
			expired.append(buff)
		else:
			_buff_remaining[buff] = remaining
	for buff in expired:
		remove_buff(buff)


func _tick_buffs(delta: float) -> void:
	var entity := get_parent()
	for buff in _active_buffs:
		if buff.tick_interval <= 0.0:
			continue
		var elapsed: float = float(_tick_elapsed.get(buff, 0.0)) + delta
		while elapsed >= buff.tick_interval:
			elapsed -= buff.tick_interval
			_apply_tick_effects(entity, buff)
		_tick_elapsed[buff] = elapsed


func _apply_tick_effects(entity: Node, buff: Buff) -> void:
	var stacks: int = _stacks.get(buff, 1)
	if buff.tick_damage > 0:
		var damage := buff.tick_damage * stacks
		if buff.tick_damage_scaling > 0.0:
			var stats := entity.get_node_or_null("StatsComponent")
			if stats and "magic_damage" in stats:
				damage += int(stats.magic_damage * buff.tick_damage_scaling)
		CombatExecutor.report_hit(entity, entity, damage, entity.global_position, null, ["dot", buff.status_id])
	if buff.tick_heal > 0 and entity.has_method("heal"):
		entity.heal(buff.tick_heal * stacks)


func _find_matching_buff(template: Buff) -> Buff:
	if not template.status_id.is_empty():
		var by_status := _find_by_status(template.status_id)
		if by_status:
			return by_status
	for active in _active_buffs:
		if active.get_runtime_id() == template.get_runtime_id():
			return active
	return null


func _find_by_status(status_id: String) -> Buff:
	for buff in _active_buffs:
		if buff.status_id == status_id:
			return buff
	return null


func _remove_by_exclusive_group(group_id: String) -> void:
	var to_remove: Array[Buff] = []
	for buff in _active_buffs:
		if buff.exclusive_group == group_id:
			to_remove.append(buff)
	for buff in to_remove:
		remove_buff(buff)


func _refresh_buff(buff: Buff, duration: float) -> void:
	if duration > 0.0:
		_buff_remaining[buff] = duration
	if buff.tick_interval > 0.0:
		_tick_elapsed[buff] = 0.0
	CombatExecutor.report_status_applied(get_parent(), buff)
	_record_buff_trace("BUFF_REFRESH", buff)
	buffs_changed.emit()


func _record_buff_trace(label: String, buff: Buff) -> void:
	var trace := CombatDebugger.active()
	if not trace:
		return
	trace.record(
		CombatTraceEvent.Category.EVENT_EMIT,
		CombatPhase.Phase.EVENT,
		"%s -> %s" % [label, get_parent().name],
		"",
		"",
		{},
		{"effect": buff.describe()}
	)
