class_name EquipmentSetBonus
extends Resource

@export_range(2, 9, 1) var required_pieces: int = 2
@export_multiline var description: String = ""
@export var stat_modifiers: Dictionary = {}
@export var stat_multipliers: Dictionary = {}
@export var combat_modifiers: Dictionary = {}
