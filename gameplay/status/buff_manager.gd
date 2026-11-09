class_name BuffManager
extends Node

signal buffs_changed
var buildup:=StatusBuildup.new()
enum RemovalReason { EXPIRED, CONSUMED, DISPELLED, REPLACED, REGION_CLEANUP, RESTORED }

var _control_immunity: Dictionary={}
var _instances: Array[StatusInstance] = []
var _status_versions: Dictionary = {}
var _serial := 0
var attributes: ActorAttributes
var source_resolver: Callable
var _in_transaction := false
var _events: Array[Dictionary] = []
var _changed := false
var _health_dirty := false
var _mana_dirty := false
var _transaction_snapshot: Dictionary = {}
var _restoring_campaign := false

func _ready() -> void:
	attributes = ActorAttributes.new(get_parent())
	var health:=get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if health: health.died.connect(_on_actor_died)
	process_mode = Node.PROCESS_MODE_DISABLED
	_register_with_simulation()

func _register_with_simulation() -> void:
	RuntimeRegistration.register_ticker(self)


func tick(delta: float) -> void:
	buildup.tick(delta)
	_tick_effects(delta)

func _tick_effects(delta: float) -> void:
	for key in _control_immunity.keys():
		_control_immunity[key]=maxf(0,float(_control_immunity[key])-delta)
		if _control_immunity[key]==0: _control_immunity.erase(key)
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

func apply_buff(buff: Buff, source: Node2D = null, skill: SkillData = null) -> bool:
	if not buff or is_immune(buff.status_id) or buff.prevents_actions and has_buff(buff.status_id):
		return false
	var duration_modifier:=0.0
	if buff.status_id in ["burning","poison"]: duration_modifier+=ActorProgression.modifier(get_parent(),"status.%s_duration"%buff.status_id)
	if buff.status_id=="frozen" and is_instance_valid(source): duration_modifier+=ActorProgression.modifier(source,"status.frozen_duration")
	if buff.duration>0 and not is_zero_approx(duration_modifier):
		var original:=buff
		buff=buff.duplicate() as Buff
		buff.set_meta("definition_path",original.get_meta("definition_path",original.resource_path))
		buff.duration*=clampf(1+duration_modifier,.25,2)
	for status in buff.cleanse_statuses:
		remove_status(status, RemovalReason.DISPELLED)
	_touch_status(buff.status_id)
	if not buff.exclusive_group.is_empty():
		for instance: StatusInstance in _instances.duplicate():
			if instance.definition.exclusive_group == buff.exclusive_group and instance.definition.get_runtime_id()!=buff.get_runtime_id():
				_remove(instance, RemovalReason.REPLACED)
	var existing := _find(buff.get_runtime_id())
	if not buff.status_id.is_empty():
		existing = _find(buff.status_id)
	if existing and buff.stack_behavior != Buff.StackBehavior.INDEPENDENT:
		existing.definition=buff
		if buff.stack_behavior == Buff.StackBehavior.INTENSITY:
			existing.stacks = mini(stack_limit(existing.definition), existing.stacks + 1)
		existing.remaining = buff.duration
		# Keep periodic progress when a status is refreshed; frequent refresh cannot prevent its tick.
		_refresh_source(existing, source, skill)
		_rebuild_attributes()
		_notify(true, existing.definition)
		return true
	_serial += 1
	var instance := StatusInstance.new(_serial, buff, source, skill)
	instance.source_resolver=source_resolver
	_instances.append(instance)
	_rebuild_attributes()
	_notify(true, buff)
	return true

func _refresh_source(instance: StatusInstance, source: Node2D, skill: SkillData) -> void:
	if is_instance_valid(source):
		instance.source_ref = weakref(source)
		instance.source_resolver=source_resolver
		instance.source_id=source.actor_context.id if "actor_context" in source and source.actor_context else ""
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
	if instance.definition.control_recovery>0 and reason not in [RemovalReason.REPLACED,RemovalReason.RESTORED,RemovalReason.REGION_CLEANUP]: _control_immunity[instance.definition.status_id]=instance.definition.control_recovery
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
	return {"instance": instance, "buff": instance.definition, "remaining": instance.remaining, "stacks": instance.stacks, "elapsed": instance.elapsed, "source_magic": instance.source_magic,"source_ref":instance.source_ref,"source_id":instance.source_id,"source_skill":instance.source_skill,"source_resolver":instance.source_resolver}

func restore_status_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var instance: StatusInstance = snapshot.instance
	instance.remaining = snapshot.remaining
	instance.stacks = snapshot.stacks
	instance.elapsed = snapshot.elapsed
	instance.source_magic = snapshot.source_magic
	instance.source_ref=snapshot.source_ref; instance.source_id=snapshot.source_id; instance.source_skill=snapshot.source_skill; instance.source_resolver=snapshot.source_resolver
	if instance not in _instances:
		_instances.append(instance)
	_touch_status(instance.definition.status_id)
	_rebuild_attributes()

func begin_transaction() -> void:
	assert(not _in_transaction)
	_transaction_snapshot = {"buildup":buildup.snapshot(),"control_immunity":_control_immunity.duplicate(),"instances": _instances.map(_snapshot), "versions": _status_versions.duplicate()}
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
			instance.source_magic=snapshot.source_magic; instance.source_ref=snapshot.source_ref; instance.source_id=snapshot.source_id; instance.source_skill=snapshot.source_skill; instance.source_resolver=snapshot.source_resolver
			_instances.append(instance)
		_control_immunity=_transaction_snapshot.get("control_immunity",{}).duplicate()
		buildup.restore(_transaction_snapshot.get("buildup",{}))
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
	if _restoring_campaign: return
	var event := {"applied": applied, "buff": buff, "reason": reason}
	if _in_transaction:
		_events.append(event)
		_changed = true
	else:
		_publish([event], true)

func _publish(events: Array, changed: bool, include_mana: bool = true) -> void:
	for event in events:
		if event.has("stacks"):
			CombatExecutor.report_status_changed(get_parent(), event.buff, event.amount, event.stacks, event.reason)
		elif event.applied:
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

func get_incoming_hit_multiplier(skill: SkillData, tags: Array) -> float:
	if not skill or skill.skill_type != SkillData.SkillType.PROJECTILE or "dot" in tags or "melee" in tags or "melee" in skill.tags:
		return 1.0
	var factor := 1.0
	for instance in _instances:
		factor *= pow(instance.definition.incoming_projectile_multiplier, instance.stacks)
	return clampf(factor, 0.1, 4.0)

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
		if (not buff.spell_tags.is_empty() or not buff.spell_elements.is_empty()) and not buff.status_id.is_empty():
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
		result.append({"id": buff.get_runtime_id(), "instance_id": instance.serial, "name": buff.display_name if not buff.display_name.is_empty() else buff.status_id, "status_id": buff.status_id, "icon": buff.icon, "remaining": instance.remaining, "duration": buff.duration, "progress": clampf(instance.remaining / buff.duration, 0, 1) if buff.duration > 0 else 1.0, "stacks": instance.stacks, "capacity": stack_limit(buff), "category": buff.category, "source": instance.source().name if is_instance_valid(instance.source()) else "环境/自身", "description": buff.describe(), "resource_path": buff.resource_path})
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
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var definition := load(path) as Buff
		if not definition:
			continue
		var buff := definition.duplicate() as Buff
		buff.duration = float(entry.get("duration", definition.duration))
		buff.set_meta("definition_path", path)
		apply_buff(buff)
		var instance := _find(buff.get_runtime_id())
		if not instance:
			continue
		instance.remaining = maxf(0, float(entry.get("remaining", buff.duration)))
		instance.stacks = clampi(int(entry.get("stacks", 1)), 1, stack_limit(buff))
		instance.elapsed = maxf(0, float(entry.get("tick_elapsed", 0)))
		instance.source_magic = float(entry.get("source_magic", 0))
	_rebuild_attributes()

func clear_all(reason: RemovalReason = RemovalReason.DISPELLED) -> void:
	buildup.clear()
	for instance: StatusInstance in _instances.duplicate():
		_remove(instance, reason)

func clear_temporary(keep_campaign := false) -> void:
	if not keep_campaign:
		buildup.clear()
		_control_immunity.clear()
	for instance: StatusInstance in _instances.duplicate():
		if not instance.definition.persistent and not (keep_campaign and _campaign_eligible(instance.definition)):
			_remove(instance, RemovalReason.REGION_CLEANUP)

func _on_actor_died() -> void:
	# Child readiness installs this before the actor publishes death/recovery.
	buildup.clear(); _control_immunity.clear()
	_restoring_campaign=true
	for instance: StatusInstance in _instances.duplicate():
		if instance.definition.duration>0 and not instance.definition.survives_death:
			_remove(instance,RemovalReason.RESTORED)
	_restoring_campaign=false
	buffs_changed.emit()

func provision(group: String) -> Dictionary:
	for instance in _instances:
		if instance.definition.provision_group==group:
			return {"id":instance.definition.provision_id,"remaining":instance.remaining}
	return {"id":"","remaining":0.0}

func set_provision(group: String,id: String,remaining: float,restoring := false) -> void:
	if group not in ["meal","water","tea"] or not is_finite(remaining): return
	var previous_restoring:=_restoring_campaign
	if restoring: _restoring_campaign=true
	for instance: StatusInstance in _instances.duplicate():
		if instance.definition.provision_group==group: _remove(instance,RemovalReason.RESTORED)
	var entry:=ProvisionCatalog.default_catalog().definition(id)
	if remaining>0 and entry and entry.effect and entry.effect.provision_group==group:
		if restoring:
			_serial+=1
			var instance:=StatusInstance.new(_serial,entry.effect)
			instance.remaining=minf(remaining,entry.effect.duration); instance.source_resolver=source_resolver
			_instances.append(instance); _rebuild_attributes()
		else:
			apply_buff(entry.effect)
			var instance:=_find(entry.effect.get_runtime_id())
			if instance: instance.remaining=minf(remaining,entry.effect.duration)
	_restoring_campaign=previous_restoring
	if restoring: buffs_changed.emit()

func provision_recovery() -> Dictionary:
	var result: Dictionary={"health_bonus":0.0,"mana_bonus":0.0,"stamina_bonus":0.0,"mana_sources":{}}
	for instance in _instances:
		var buff:=instance.definition
		if buff.provision_group.is_empty(): continue
		result.health_bonus+=buff.health_recovery_bonus
		result.mana_bonus+=buff.mana_recovery_bonus
		result.stamina_bonus+=buff.stamina_recovery_bonus
		result.mana_sources["food" if buff.provision_group=="meal" else buff.provision_group]=buff.mana_recovery_bonus
	return result

static func _campaign_path(definition: Buff) -> String:
	return str(definition.get_meta("definition_path",definition.resource_path))
static func _campaign_eligible(definition: Buff) -> bool:
	return definition.duration>0 and definition.exclusive_group!="stored_energy" and not _campaign_path(definition).is_empty()
static func campaign_definition(path: String) -> Buff:
	if not path.ends_with(".tres") or not (path.begins_with("res://content/") or path.begins_with("res://gameplay/abilities/data/")) or not ResourceLoader.exists(path): return null
	var definition:=load(path) as Buff
	return definition if definition and definition.exclusive_group!="stored_energy" else null

func campaign_state() -> Dictionary:
	var entries: Array[Dictionary]=[]
	for instance in _instances:
		if not _campaign_eligible(instance.definition): continue
		entries.append({"path":_campaign_path(instance.definition),"id":instance.definition.get_runtime_id(),"duration":instance.definition.duration,"remaining":instance.remaining,"stacks":instance.stacks,"elapsed":instance.elapsed,"source_magic":instance.source_magic,"source_id":instance.source_id})
	return {"schema":1,"entries":entries,"immunity":_control_immunity.duplicate()}

static func valid_campaign_state(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or not data.get("entries") is Array or data.entries.size()>64 or not data.get("immunity") is Dictionary or data.immunity.size()>64: return false
	var unique: Dictionary={}
	var groups: Dictionary={}
	for entry in data.entries:
		if not entry is Dictionary or not entry.get("path") is String or not entry.get("id") is String or not entry.get("source_id","") is String or str(entry.get("source_id","")).length()>256: return false
		var definition:=campaign_definition(entry.path)
		if not definition or definition.get_runtime_id()!=entry.id or not entry.get("stacks") is int or entry.stacks<1 or entry.stacks>maxi(64,definition.max_stacks): return false
		if unique.has(entry.id) and definition.stack_behavior!=Buff.StackBehavior.INDEPENDENT: return false
		unique[entry.id]=true
		if not definition.exclusive_group.is_empty():
			if groups.has(definition.exclusive_group) and groups[definition.exclusive_group]!=entry.id: return false
			groups[definition.exclusive_group]=entry.id
		for key in ["duration","remaining","elapsed","source_magic"]:
			if typeof(entry.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(entry[key])) or float(entry[key])<0: return false
		if entry.duration<=0 or entry.duration>86400 or entry.remaining<=0 or entry.remaining>entry.duration or entry.source_magic>1000000: return false
		if entry.elapsed>maxf(0,definition.tick_interval)+.00001: return false
	for key in data.immunity:
		var value=data.immunity[key]
		if not key is String or key.is_empty() or typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<=0 or value>86400: return false
	return true

func restore_campaign_state(data: Dictionary,resolver: Callable=Callable()) -> void:
	if not valid_campaign_state(data): return
	_restoring_campaign=true
	# Equipment's permanent contribution remains owned by EquipmentManager.
	for instance: StatusInstance in _instances.duplicate():
		if not instance.definition.persistent or instance.definition.duration>0: _remove(instance,RemovalReason.RESTORED)
	_control_immunity=data.immunity.duplicate()
	for entry in data.entries:
		var definition:=campaign_definition(entry.path).duplicate() as Buff
		definition.duration=float(entry.duration); definition.set_meta("definition_path",entry.path)
		_serial+=1
		var instance:=StatusInstance.new(_serial,definition)
		instance.remaining=float(entry.remaining); instance.elapsed=float(entry.elapsed)
		instance.stacks=clampi(entry.stacks,1,stack_limit(definition)); instance.source_magic=float(entry.source_magic)
		instance.source_id=str(entry.get("source_id","")); instance.source_resolver=resolver
		_instances.append(instance)
	_rebuild_attributes()
	_restoring_campaign=false
	buffs_changed.emit()

## Settle a finite backlog at status/tick/immunity boundaries, never moving bodies
## or replaying old on-apply/on-expire visual/proc events in the new region.
func advance_campaign_time(seconds: float) -> void:
	buildup.tick(seconds)
	_restoring_campaign=true
	var left:=seconds
	while left>.000001 and (not _instances.is_empty() or not _control_immunity.is_empty()):
		var step:=left
		var timed:=false
		for instance in _instances:
			if instance.definition.duration<=0: continue
			timed=true; step=minf(step,instance.remaining)
			if instance.definition.tick_interval>0: step=minf(step,maxf(.000001,instance.definition.tick_interval-instance.elapsed))
		for value in _control_immunity.values(): timed=true; step=minf(step,float(value))
		if not timed: break
		step=maxf(.000001,step)
		_tick_effects(step); left-=step
		var health:=get_parent().get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_dead: break
	_restoring_campaign=false
	buffs_changed.emit()

func accumulate_enchantment(definition: WeaponEnchantment,amount: float,source: Node2D,skill: SkillData) -> bool:
	if is_immune(definition.status.status_id) or has_buff(definition.status.status_id): return false
	if not buildup.add(definition,amount): return false
	return apply_buff(definition.status,source,skill)

func _apply_tick(instance: StatusInstance) -> void:
	var buff := instance.definition
	var entity := get_parent() as Node2D
	if buff.tick_damage > 0:
		var damage := buff.tick_damage * instance.stacks + int(instance.source_magic * buff.tick_damage_scaling)
		CombatExecutor.report_hit(instance.source(), entity, damage, entity.global_position, instance.source_skill, ["dot", buff.status_id])
	if buff.tick_heal > 0 and entity.has_method("heal"):
		entity.heal(buff.tick_heal * instance.stacks)

func stack_limit(buff: Buff) -> int:
	var extra := 0
	var equipment := get_parent().get_node_or_null("EquipmentManager") as EquipmentManager
	if equipment and not buff.capacity_key.is_empty():
		extra = int(equipment.casting_value(buff.capacity_key))
	return maxi(1, buff.max_stacks + extra)

func is_immune(status: String) -> bool:
	if _control_immunity.has(status): return true
	if status.is_empty():
		return false
	if status == "burning" and get_parent().is_in_group("fire_immune"):
		return true
	for instance in _instances:
		if status in instance.definition.status_immunities:
			return true
	return false

## amount=0 preserves the legacy whole-status consumption contract.
func consume_duration(id: String, retained_fraction: float = 0.5) -> bool:
	var instance := _find(id)
	if not instance or not instance.definition.can_empower or instance.definition.duration <= 0 or instance.remaining <= 0 or retained_fraction <= 0 or retained_fraction >= 1:
		return false
	instance.remaining *= retained_fraction
	_touch_status(id)
	_notify_stacks(instance.definition, 0, instance.stacks, "partially_consumed")
	return true

func consume_status(id: String, amount: int = 0) -> bool:
	var instance := _find(id)
	if not instance or amount < 0 or (amount > 0 and instance.stacks < amount):
		return false
	var spent := amount if amount > 0 else instance.stacks
	var left := instance.stacks - spent
	if left == 0:
		_remove(instance, RemovalReason.CONSUMED)
	else:
		instance.stacks = left
		_touch_status(id)
		_rebuild_attributes()
	_notify_stacks(instance.definition, spent, left, "consumed")
	return true

func _notify_stacks(buff: Buff, amount: int, stacks: int, reason: String) -> void:
	var event := {"buff": buff, "amount": amount, "stacks": stacks, "reason": reason}
	if _in_transaction:
		_events.append(event)
		_changed = true
	else:
		_publish([event], true)

func reconcile_stack_limits() -> void:
	for instance in _instances:
		var limit := stack_limit(instance.definition)
		if instance.stacks > limit:
			var removed := instance.stacks - limit
			instance.stacks = limit
			_touch_status(instance.definition.status_id)
			_rebuild_attributes()
			_notify_stacks(instance.definition, removed, limit, "capacity_changed")

func prevents_actions() -> bool:
	for instance in _instances:
		if instance.definition.prevents_actions: return true
	return false

## Frozen legacy projection. Current food/drink definitions use ProvisionCatalog.
const PROVISION_BUFFS := ["meal_fortitude","broth_fortitude","guard_tonic","clear_tonic"]
func provision_state() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for entry in serialize_state():
		if entry.runtime_id in PROVISION_BUFFS: result.append({"id":entry.runtime_id,"remaining":entry.remaining})
	return result
static func valid_provisions(entries: Variant) -> bool:
	if not entries is Array or entries.size()>PROVISION_BUFFS.size(): return false
	var seen: Dictionary={}
	for entry in entries:
		if not entry is Dictionary or entry.get("id","") not in PROVISION_BUFFS or seen.has(entry.id) or typeof(entry.get("remaining")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(entry.remaining)) or entry.remaining<=0: return false
		var definition:=load("res://content/status/%s.tres"%entry.id) as Buff
		if entry.remaining>definition.duration: return false
		seen[entry.id]=true
	return true
func restore_provisions(entries: Array) -> void:
	if not valid_provisions(entries): return
	for entry in entries:
		var definition:=load("res://content/status/%s.tres"%entry.id) as Buff
		apply_buff(definition)
		var instance:=_find(definition.get_runtime_id())
		if instance: instance.remaining=float(entry.remaining)
