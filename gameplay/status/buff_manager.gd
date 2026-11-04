class_name BuffManager
extends Node

signal buffs_changed
enum RemovalReason { EXPIRED, CONSUMED, DISPELLED, REPLACED, REGION_CLEANUP, RESTORED }

var _instances: Array[StatusInstance] = []
var _status_versions: Dictionary = {}
var _serial := 0
var attributes: ActorAttributes
var _in_transaction := false
var _events: Array[Dictionary] = []
var _changed := false
var _health_dirty := false
var _mana_dirty := false
var _transaction_snapshot: Dictionary = {}

func _ready() -> void:
	attributes = ActorAttributes.new(get_parent())
	process_mode = Node.PROCESS_MODE_DISABLED
	_register_with_simulation()

func _register_with_simulation() -> void:
	RuntimeRegistration.register_ticker(self)


func tick(delta: float) -> void:
	for instance: StatusInstance in _instances.duplicate():
		if instance not in _instances:
			continue
		var alive_time := minf(delta, maxf(0.0, instance.remaining)) if instance.definition.duration > 0 else delta
		var interval := instance.definition.tick_interval
		if interval > 0:
			instance.elapsed += alive_time
			while instance.elapsed + 0.000001 >= interval and instance in _instances:
				instance.elapsed = maxf(0.0, instance.elapsed - interval)
				_apply_tick(instance)
		if instance.definition.duration > 0 and instance in _instances:
			instance.remaining = maxf(0.0, instance.remaining - delta)
			if instance.remaining <= 0.000001:
				_remove(instance, RemovalReason.EXPIRED)

func apply_buff(buff: Buff, source: Node2D = null, skill: SkillData = null) -> void:
	if not buff:
		return
	_touch_status(buff.status_id)
	if not buff.exclusive_group.is_empty():
		for instance: StatusInstance in _instances.duplicate():
			if instance.definition.exclusive_group == buff.exclusive_group:
				_remove(instance, RemovalReason.REPLACED)
	var existing := _find(buff.get_runtime_id())
	if not buff.status_id.is_empty():
		existing = _find(buff.status_id)
	if existing and buff.stack_behavior != Buff.StackBehavior.INDEPENDENT:
		if buff.stack_behavior == Buff.StackBehavior.INTENSITY:
			existing.stacks = mini(existing.definition.max_stacks, existing.stacks + 1)
		existing.remaining = buff.duration
		# Keep periodic progress when a status is refreshed; frequent refresh cannot prevent its tick.
		_refresh_source(existing, source, skill)
		_rebuild_attributes()
		_notify(true, existing.definition)
		return
	_serial += 1
	var instance := StatusInstance.new(_serial, buff, source, skill)
	_instances.append(instance)
	_rebuild_attributes()
	_notify(true, buff)

func _refresh_source(instance: StatusInstance, source: Node2D, skill: SkillData) -> void:
	if is_instance_valid(source):
		instance.source_ref = weakref(source)
		instance.source_skill = skill
		var stats := source.get_node_or_null("StatsComponent")
		instance.source_magic = stats.magic_damage if stats else 0.0

func remove_buff(buff: Buff, reason: RemovalReason = RemovalReason.DISPELLED) -> void:
	for instance: StatusInstance in _instances.duplicate():
		if instance.definition == buff:
			_remove(instance, reason)
			return

func _remove(instance: StatusInstance, reason: RemovalReason) -> void:
	if instance not in _instances:
		return
	_instances.erase(instance)
	_touch_status(instance.definition.status_id)
	_rebuild_attributes()
	_notify(false, instance.definition, reason)

func has_buff(id: String) -> bool:
	return _find(id) != null

func _find(id: String) -> StatusInstance:
	for instance in _instances:
		var buff := instance.definition
		if id in [buff.status_id, buff.get_runtime_id(), buff.display_name]:
			return instance
	return null

func _touch_status(id: String) -> void:
	if not id.is_empty():
		_status_versions[id] = status_version(id) + 1

func status_version(id: String) -> int:
	return int(_status_versions.get(id, 0))

func capture_status(id: String) -> Dictionary:
	var instance := _find(id)
	return _snapshot(instance) if instance else {}

func _snapshot(instance: StatusInstance) -> Dictionary:
	return {"instance": instance, "buff": instance.definition, "remaining": instance.remaining, "stacks": instance.stacks, "elapsed": instance.elapsed, "source_magic": instance.source_magic}

func restore_status_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var instance: StatusInstance = snapshot.instance
	instance.remaining = snapshot.remaining
	instance.stacks = snapshot.stacks
	instance.elapsed = snapshot.elapsed
	instance.source_magic = snapshot.source_magic
	if instance not in _instances:
		_instances.append(instance)
	_touch_status(instance.definition.status_id)
	_rebuild_attributes()

func begin_transaction() -> void:
	assert(not _in_transaction)
	_transaction_snapshot = {"instances": _instances.map(_snapshot), "versions": _status_versions.duplicate()}
	_in_transaction = true
	_events.clear()
	_changed = false
	_health_dirty = false
	_mana_dirty = false

func finish_transaction(commit: bool) -> Callable:
	if not _in_transaction:
		return Callable()
	if not commit:
		_instances.clear()
		for snapshot: Dictionary in _transaction_snapshot.instances:
			var instance: StatusInstance = snapshot.instance
			instance.remaining = snapshot.remaining
			instance.stacks = snapshot.stacks
			instance.elapsed = snapshot.elapsed
			_instances.append(instance)
		_status_versions = _transaction_snapshot.versions
		_rebuild_attributes()
		_health_dirty = false
		_mana_dirty = false
	var events := _events.duplicate() if commit else []
	var changed := _changed and commit
	_events.clear()
	_transaction_snapshot.clear()
	_in_transaction = false
	_changed = false
	return _publish.bind(events, changed, false)

func _notify(applied: bool, buff: Buff, reason: RemovalReason = RemovalReason.DISPELLED) -> void:
	var event := {"applied": applied, "buff": buff, "reason": reason}
	if _in_transaction:
		_events.append(event)
		_changed = true
	else:
		_publish([event], true)

func _publish(events: Array, changed: bool, include_mana: bool = true) -> void:
	for event in events:
		if event.applied:
			CombatExecutor.report_status_applied(get_parent(), event.buff)
		else:
			CombatExecutor.report_status_removed(get_parent(), event.buff, RemovalReason.keys()[event.reason].to_lower())
	if changed:
		_emit_attributes(include_mana)
		buffs_changed.emit()

func _rebuild_attributes() -> void:
	if not attributes:
		attributes = ActorAttributes.new(get_parent())
	var health := get_parent().get_node_or_null("HealthComponent") as HealthComponent
	var mana := get_parent().get_node_or_null("ManaComponent") as ManaComponent
	var old_max_hp := health.max_hp if health else 0
	var old_hp := health.hp if health else 0
	var old_max_mp := mana.max_mp if mana else 0
	var old_mp := mana.mp if mana else 0
	var stats := get_parent().get_node_or_null("StatsComponent") as StatsComponent
	if stats:
		stats._recalculate_all()
	if get_parent().has_method("_apply_stats"):
		get_parent()._apply_stats()
	attributes.rebuild(_instances)
	if health:
		health.hp = clampi(old_hp + health.max_hp - old_max_hp, 0 if health.is_dead else 1, health.max_hp)
		_health_dirty = _health_dirty or health.hp != old_hp or health.max_hp != old_max_hp
	if mana:
		mana.mp = clampi(old_mp + mana.max_mp - old_max_mp, 0, mana.max_mp)
		_mana_dirty = _mana_dirty or mana.mp != old_mp or mana.max_mp != old_max_mp

func set_base_attributes(values: Dictionary) -> void:
	if not attributes:
		attributes = ActorAttributes.new(get_parent())
	attributes.set_bases(values)
	attributes.rebuild(_instances)

func effective_primary(key: String, base: int) -> int:
	if not attributes:
		return base
	return attributes.primary_value(key, base, _instances)

func _emit_attributes(include_mana: bool = true) -> void:
	var health := get_parent().get_node_or_null("HealthComponent") as HealthComponent
	var mana := get_parent().get_node_or_null("ManaComponent") as ManaComponent
	if health and _health_dirty:
		health.health_changed.emit(health.hp, health.max_hp)
	if mana and include_mana and _mana_dirty:
		mana.notify_changed()
	_health_dirty = false
	_mana_dirty = false

func get_damage_taken_multiplier() -> float:
	var result := 1.0
	for instance in _instances:
		result *= pow(instance.definition.damage_taken_multiplier, instance.stacks)
	return clampf(result, 0.1, 4.0)

func get_speed_multiplier() -> float:
	var result := 1.0
	for instance in _instances:
		result *= pow(instance.definition.speed_multiplier, instance.stacks)
	return result

func get_attack_tags() -> Array[String]:
	var tags: Array[String] = []
	for instance in _instances:
		for tag in instance.definition.attack_tags:
			if tag not in tags:
				tags.append(tag)
	return tags

func get_spell_boons() -> Array[Buff]:
	var result: Array[Buff] = []
	for instance in _instances:
		var buff := instance.definition
		if not buff.spell_tags.is_empty() and not buff.status_id.is_empty():
			result.append(buff)
	return result

func remove_status(id: String, reason: RemovalReason = RemovalReason.DISPELLED) -> bool:
	var instance := _find(id)
	if not instance:
		return false
	_remove(instance, reason)
	return true

func get_active_statuses() -> Array[String]:
	var result: Array[String] = []
	for instance in _instances:
		if not instance.definition.status_id.is_empty():
			result.append(instance.definition.status_id)
	return result

func get_stack_count(id: String) -> int:
	var instance := _find(id)
	return instance.stacks if instance else 0

func get_active_buff_entries() -> Array:
	var result: Array = []
	for instance in _instances:
		var buff := instance.definition
		result.append({"id": buff.get_runtime_id(), "instance_id": instance.serial, "name": buff.display_name if not buff.display_name.is_empty() else buff.status_id, "status_id": buff.status_id, "icon": buff.icon, "remaining": instance.remaining, "duration": buff.duration, "progress": clampf(instance.remaining / buff.duration, 0, 1) if buff.duration > 0 else 1.0, "stacks": instance.stacks, "description": buff.describe(), "resource_path": buff.resource_path})
	return result

func serialize_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in _instances:
		result.append({"resource_path": instance.definition.get_meta("definition_path", instance.definition.resource_path), "runtime_id": instance.definition.get_runtime_id(), "duration": instance.definition.duration, "remaining": instance.remaining, "stacks": instance.stacks, "tick_elapsed": instance.elapsed, "source_magic": instance.source_magic})
	return result

func restore_state(entries: Array[Dictionary]) -> void:
	clear_all(RemovalReason.RESTORED)
	for entry in entries:
		var path := str(entry.get("resource_path", ""))
		if path.is_empty():
			continue
		var definition := load(path) as Buff
		if not definition:
			continue
		var buff := definition.duplicate() as Buff
		buff.duration = float(entry.get("duration", definition.duration))
		buff.set_meta("definition_path", path)
		apply_buff(buff)
		var instance := _find(buff.get_runtime_id())
		instance.remaining = maxf(0, float(entry.get("remaining", buff.duration)))
		instance.stacks = clampi(int(entry.get("stacks", 1)), 1, maxi(1, buff.max_stacks))
		instance.elapsed = maxf(0, float(entry.get("tick_elapsed", 0)))
		instance.source_magic = float(entry.get("source_magic", 0))
	_rebuild_attributes()

func clear_all(reason: RemovalReason = RemovalReason.DISPELLED) -> void:
	for instance: StatusInstance in _instances.duplicate():
		_remove(instance, reason)

func clear_temporary() -> void:
	for instance: StatusInstance in _instances.duplicate():
		if not instance.definition.persistent:
			_remove(instance, RemovalReason.REGION_CLEANUP)

func _apply_tick(instance: StatusInstance) -> void:
	var buff := instance.definition
	var entity := get_parent() as Node2D
	if buff.tick_damage > 0:
		var damage := buff.tick_damage * instance.stacks + int(instance.source_magic * buff.tick_damage_scaling)
		CombatExecutor.report_hit(instance.source(), entity, damage, entity.global_position, instance.source_skill, ["dot", buff.status_id])
	if buff.tick_heal > 0 and entity.has_method("heal"):
		entity.heal(buff.tick_heal * instance.stacks)
