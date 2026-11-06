class_name SkillSynergyResolver
extends Node
signal reaction_triggered(title: String, position: Vector2)
signal reaction_observed(id: String, position: Vector2)
signal reaction_recorded(details: Dictionary)

var _owner_entity: Node2D = null
var _cooldowns: Dictionary = {}


func setup(owner_entity: Node2D) -> void:
	_owner_entity = owner_entity
	if CombatEventBus.instance:
		CombatEventBus.instance.subscribe(CombatEvent.Type.ON_HIT, _on_hit)


func _exit_tree() -> void:
	if CombatEventBus.instance:
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_HIT, _on_hit)


func _ready() -> void:
	set_process(false)
	RuntimeRegistration.register_ticker(self)

func tick(delta: float) -> void:
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(0, float(_cooldowns[key]) - delta)
		if _cooldowns[key] <= 0:
			_cooldowns.erase(key)


func _on_hit(event: CombatEvent) -> void:
	if "dot" in event.data.get("tags", []):
		return
	if event.source != _owner_entity or not event.skill or not is_instance_valid(event.target):
		return
	for synergy in ElementReactionCatalog.for_skill(event.skill):
		if _can_trigger(synergy, event):
			_trigger(synergy, event)

func _cooldown_key(synergy: SkillSynergyData, target: Node2D) -> String:
	return "%s:%s" % [synergy.id, target.get_instance_id()]

func _can_trigger(synergy: SkillSynergyData, event: CombatEvent) -> bool:
	if float(_cooldowns.get(_cooldown_key(synergy, event.target), 0)) > 0:
		return false
	var target_buffs := event.target.get_node_or_null("BuffManager") as BuffManager
	var caster_buffs := _owner_entity.get_node_or_null("BuffManager") as BuffManager
	var target_statuses: Array = event.data.get("target_statuses_before", target_buffs.get_active_statuses() if target_buffs else [])
	var caster_statuses: Array = event.data.get("source_statuses_before", caster_buffs.get_active_statuses() if caster_buffs else [])
	if not synergy.required_target_status.is_empty() and synergy.required_target_status not in target_statuses:
		return false
	if not synergy.required_caster_status.is_empty() and synergy.required_caster_status not in caster_statuses:
		return false
	return synergy.trigger_chance >= 1.0 or randf() < synergy.trigger_chance


func _trigger(synergy: SkillSynergyData, event: CombatEvent) -> void:
	if synergy.cooldown > 0:
		_cooldowns[_cooldown_key(synergy, event.target)] = synergy.cooldown
	var damage := int(round(float(event.data.get("damage", 0)) * synergy.bonus_damage_ratio))
	if damage > 0:
		var tags: Array = ["synergy", synergy.id]
		tags.append_array(synergy.bonus_tags)
		CombatExecutor.report_bonus_damage(_owner_entity, event.target, damage, event.skill, tags)
	if synergy.consume_target_status:
		var target_buffs := event.target.get_node_or_null("BuffManager") as BuffManager
		if target_buffs:
			target_buffs.remove_status(synergy.required_target_status)
	if damage > 0 or synergy.consume_target_status:
		reaction_recorded.emit({"reaction": "hit:" + synergy.id, "skill": event.skill.get_id(), "source": event.skill.display_name, "tags": event.data.get("tags", []).duplicate(), "prior_target_statuses": event.data.get("target_statuses_before", []).duplicate(), "required_status": synergy.required_target_status, "consumed": synergy.consume_target_status, "position": [event.target.global_position.x, event.target.global_position.y]})
		reaction_observed.emit(synergy.id, event.target.global_position)
		reaction_triggered.emit("灭火" if synergy.id == "steam_burst" and damage == 0 else synergy.display_name, event.target.global_position)
	if not synergy.triggered_skill_id.is_empty():
		_cast_triggered_skill(synergy.triggered_skill_id, event.target)


func _cast_triggered_skill(skill_id: String, target: Node2D) -> void:
	var manager := _owner_entity.get_node_or_null("SkillManager") as SkillManager
	if not manager or not manager.pool or not manager.executor:
		return
	var skill := manager.pool.get_skill(skill_id)
	if not skill:
		return
	var direction := (_owner_entity.global_position.direction_to(target.global_position)).normalized()
	var context := CastContext.simple(_owner_entity, direction, skill)
	context.target = target
	context.target_position = target.global_position
	manager.executor.execute(skill.create_runtime_variant(), context)
