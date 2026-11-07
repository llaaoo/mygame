class_name DamageNumberSpawner
extends Node
## Shows combat feedback in the target's world so it leaves with the region.

var _bus: CombatEventBus


func _init(bus: CombatEventBus) -> void:
	_bus = bus


func _ready() -> void:
	_bus.subscribe(CombatEvent.Type.ON_DAMAGE, _on_damage)
	_bus.subscribe(CombatEvent.Type.ON_HEAL, _on_heal)
	_bus.subscribe(CombatEvent.Type.ON_DODGE, _on_dodge)
	_bus.subscribe(CombatEvent.Type.ON_CRIT, _on_crit)


func _exit_tree() -> void:
	if not is_instance_valid(_bus):
		return
	_bus.unsubscribe(CombatEvent.Type.ON_DAMAGE, _on_damage)
	_bus.unsubscribe(CombatEvent.Type.ON_HEAL, _on_heal)
	_bus.unsubscribe(CombatEvent.Type.ON_DODGE, _on_dodge)
	_bus.unsubscribe(CombatEvent.Type.ON_CRIT, _on_crit)


func _on_damage(event: CombatEvent) -> void:
	_show_damage(event, false)


func _on_crit(event: CombatEvent) -> void:
	_show_damage(event, true)


func _show_damage(event: CombatEvent, critical: bool) -> void:
	var amount: int = event.data.get("damage", 0)
	var world := _target_world(event.target)
	if amount > 0 and world:
		DamageNumber.spawn_damage(world, amount, event.target.global_position, critical)


func _on_heal(event: CombatEvent) -> void:
	var amount: int = event.data.get("amount", 0)
	var world := _target_world(event.target)
	if amount > 0 and world:
		DamageNumber.spawn_heal(world, amount, event.target.global_position)


func _on_dodge(event: CombatEvent) -> void:
	var world := _target_world(event.target)
	if world:
		DamageNumber.spawn_miss(world, event.target.global_position)


func _target_world(target: Node2D) -> Node:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return null
	var world := WorldScope.resolve(target)
	if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion():
		return world
	return null
