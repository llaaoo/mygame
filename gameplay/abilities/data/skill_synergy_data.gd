class_name SkillSynergyData
extends Resource
## Declarative cross-spell interaction resolved from CombatEventBus ON_HIT events.

@export var id: String = ""
@export var display_name: String = "联动"
@export_multiline var description: String = ""
@export var required_target_status: String = ""
@export var required_caster_status: String = ""
@export var bonus_damage_ratio: float = 0.0
@export var consume_target_status: bool = false
@export var triggered_skill_id: String = ""
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 1.0
@export var cooldown: float = 0.0
@export var bonus_tags: Array[String] = []
