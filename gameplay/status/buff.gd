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
@export var persistent := false
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
@export var damage_taken_multiplier: float = 1.0
@export var attack_tags: Array[String] = []
@export var spell_tags: Array[String] = []
@export var spell_damage_multiplier := 1.0
@export var can_empower := false
@export var empower_name: String = ""
@export var empower_damage_multiplier := 1.0
@export var empower_mana_cost := 0
@export var empower_radius_bonus := 0.0
@export var empower_pierce_bonus := 0
@export var empower_projectile_count := 0
@export var empower_projectile_spread := 0.0
@export var empower_surface: String = ""
@export var empower_surface_radius := 0.0
@export var empower_surface_duration := 0.0

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
	if damage_taken_multiplier != 1.0:
		parts.append("受到伤害 x%.2f" % damage_taken_multiplier)
	if not attack_tags.is_empty():
		var attack_elements: Array[String] = []
		for tag in attack_tags:
			attack_elements.append({"fire": "火焰", "ice": "冰霜", "lightning": "雷电"}.get(tag, tag))
		parts.append("近战附加" + "/".join(attack_elements))
	if spell_damage_multiplier != 1.0:
		var elements: Array[String] = []
		for tag in spell_tags:
			elements.append({"fire": "火焰", "ice": "冰霜", "lightning": "雷电"}.get(tag, tag))
		parts.append("%s法术伤害 x%.2f（保留）" % ["/".join(elements), spell_damage_multiplier])
	if can_empower:
		parts.append("Shift消耗：%s（额外%d MP）" % [empower_name, empower_mana_cost])

	var effect_str := ", ".join(parts) if not parts.is_empty() else "no modifiers"
	var duration_str := " %.1fs" % duration if duration > 0.0 else " permanent"
	return "%s: %s%s" % [name, effect_str, duration_str]
