class_name Buff
extends Resource

enum Category { BUFF, DEBUFF, DOT, CONTROL, AURA }
enum StackBehavior { REFRESH, INTENSITY, INDEPENDENT }

@export var buff_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var status_id: String = ""
@export var category: Category = Category.BUFF
@export var exclusive_group: String = ""
@export var duration: float = 0.0
@export var tick_interval: float = 0.0
@export var stack_behavior: StackBehavior = StackBehavior.REFRESH
@export var max_stacks: int = 1
@export var stat_modifiers: Dictionary = {}
@export var stat_multipliers: Dictionary = {}
@export var tick_heal: int = 0
@export var tick_damage: int = 0
@export var tick_damage_scaling: float = 0.0
@export var speed_multiplier: float = 1.0

const PRIMARY_STATS: Array[String] = ["strength", "intelligence", "agility", "endurance"]


func get_runtime_id() -> String:
	if not buff_id.is_empty():
		return buff_id
	if not status_id.is_empty():
		return status_id
	if not resource_path.is_empty():
		return resource_path
	return display_name


func describe() -> String:
	var parts: Array[String] = []
	var name := display_name if not display_name.is_empty() else "Unnamed Buff"

	for stat in stat_modifiers:
		var value: float = stat_modifiers[stat]
		var sign := "+" if value >= 0 else ""
		parts.append("%s%s%d" % [stat, sign, int(value)])

	for stat in stat_multipliers:
		var mul: float = stat_multipliers[stat]
		var sign := "+" if mul >= 0 else ""
		parts.append("%s%s%d%%" % [stat, sign, int(mul * 100.0)])

	if tick_damage > 0:
		parts.append("DOT %d/%.1fs" % [tick_damage, tick_interval])
	if tick_heal > 0:
		parts.append("HOT %d/%.1fs" % [tick_heal, tick_interval])
	if speed_multiplier != 1.0:
		parts.append("speed x%.2f" % speed_multiplier)

	var effect_str := ", ".join(parts) if not parts.is_empty() else "no modifiers"
	var duration_str := " %.1fs" % duration if duration > 0.0 else " permanent"
	return "%s: %s%s" % [name, effect_str, duration_str]


func apply_to(entity: Node) -> void:
	if not entity:
		return
	for stat_name in stat_modifiers:
		_apply_stat(entity, stat_name, stat_modifiers[stat_name])
	if speed_multiplier != 1.0 and "move_speed" in entity:
		entity.move_speed *= speed_multiplier


func remove_from(entity: Node) -> void:
	if not entity:
		return
	for stat_name in stat_modifiers:
		_apply_stat(entity, stat_name, -float(stat_modifiers[stat_name]))
	if speed_multiplier != 1.0 and "move_speed" in entity and speed_multiplier != 0.0:
		entity.move_speed /= speed_multiplier


func _apply_stat(entity: Node, stat_name: String, amount: float) -> void:
	var amt := int(amount)
	if amt == 0:
		return

	if stat_name in PRIMARY_STATS:
		var stats := _get_stats_component(entity)
		if stats:
			stats.modify_stat(stat_name, amt)
		return

	if stat_name == "max_hp":
		var hp := entity.get_node_or_null("HealthComponent") as HealthComponent
		if hp:
			hp.max_hp += amt
			hp.hp = clampi(hp.hp + amt, 1, hp.max_hp)
			hp.health_changed.emit(hp.hp, hp.max_hp)
		return

	if stat_name == "attack_damage":
		var combat := entity.get_node_or_null("CombatComponent") as CombatComponent
		if combat:
			combat.attack_damage += amt
		return

	if stat_name in entity:
		entity.set(stat_name, entity.get(stat_name) + amt)


func _get_stats_component(entity: Node) -> StatsComponent:
	if entity is Player:
		return entity.stats_component
	return entity.get_node_or_null("StatsComponent") as StatsComponent
