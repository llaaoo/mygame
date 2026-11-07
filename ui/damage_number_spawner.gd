class_name DamageNumberSpawner
extends Node
## Shows combat feedback in the target's world so it leaves with the region.

var _bus: CombatEventBus
var _executor: CombatExecutor


func _init(bus: CombatEventBus,executor: CombatExecutor = null) -> void:
	_bus = bus
	_executor=executor


func _ready() -> void:
	if _executor: _executor.defense_resolved.connect(_on_defense)
	_bus.subscribe(CombatEvent.Type.ON_DAMAGE, _on_damage)
	_bus.subscribe(CombatEvent.Type.ON_HEAL, _on_heal)
	_bus.subscribe(CombatEvent.Type.ON_DODGE, _on_dodge)
	_bus.subscribe(CombatEvent.Type.ON_CRIT, _on_crit)


func _exit_tree() -> void:
	if is_instance_valid(_executor) and _executor.defense_resolved.is_connected(_on_defense): _executor.defense_resolved.disconnect(_on_defense)
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


func _on_defense(target: Node2D,outcome: Dictionary) -> void:
	var world:=_target_world(target)
	if not world: return
	var title: String="精准格挡" if outcome.get("parried",false) else "打断" if outcome.get("interrupted",false) else "击退" if outcome.get("pushed",false) else "闪避" if outcome.dodged else "破防" if outcome.guard_broken else "格挡·减伤" if outcome.damage>0 else "格挡"
	DamageNumber.spawn_reaction(world,title,target.global_position)
