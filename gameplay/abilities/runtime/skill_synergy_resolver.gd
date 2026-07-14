class_name SkillSynergyResolver
extends Node

var _owner_entity: Node2D = null
var _cooldowns: Dictionary = {}


func setup(owner_entity: Node2D) -> void:
	_owner_entity = owner_entity
	if CombatEventBus.instance:
		CombatEventBus.instance.subscribe(CombatEvent.Type.ON_HIT, _on_hit)


func _exit_tree() -> void:
	if CombatEventBus.instance:
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_HIT, _on_hit)


func _process(delta: float) -> void:
	for synergy_id in _cooldowns.keys():
		_cooldowns[synergy_id] = maxf(0.0, float(_cooldowns[synergy_id]) - delta)


func _on_hit(event: CombatEvent) -> void:
	if event.source != _owner_entity or not event.skill or not is_instance_valid(event.target):
		return
	for synergy_resource in event.skill.synergies:
		var synergy := synergy_resource as SkillSynergyData
		if not synergy or not _can_trigger(synergy, event.target):
			continue
		_trigger(synergy, event)


func _can_trigger(synergy: SkillSynergyData, target: Node2D) -> bool:
	if float(_cooldowns.get(synergy.id, 0.0)) > 0.0 or randf() > synergy.trigger_chance:
		return false
	if not synergy.required_target_status.is_empty():
		var target_buffs := target.get_node_or_null("BuffManager") as BuffManager
		if not target_buffs or not target_buffs.has_buff(synergy.required_target_status):
			return false
	if not synergy.required_caster_status.is_empty():
		var caster_buffs := _owner_entity.get_node_or_null("BuffManager") as BuffManager
		if not caster_buffs or not caster_buffs.has_buff(synergy.required_caster_status):
			return false
	return true


func _trigger(synergy: SkillSynergyData, event: CombatEvent) -> void:
	_cooldowns[synergy.id] = synergy.cooldown
	var damage := int(round(float(event.data.get("damage", 0)) * synergy.bonus_damage_ratio))
	if damage > 0:
		var tags: Array = ["synergy", synergy.id]
		tags.append_array(synergy.bonus_tags)
		CombatExecutor.report_bonus_damage(_owner_entity, event.target, damage, event.skill, tags)
	if synergy.consume_target_status:
		var target_buffs := event.target.get_node_or_null("BuffManager") as BuffManager
		if target_buffs:
			target_buffs.remove_status(synergy.required_target_status)
	if not synergy.triggered_skill_id.is_empty():
		_cast_triggered_skill(synergy.triggered_skill_id, event.target)


func _cast_triggered_skill(skill_id: String, target: Node2D) -> void:
	var player := _owner_entity as Player
	if not player:
		return
	var manager := player.skill_manager
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
