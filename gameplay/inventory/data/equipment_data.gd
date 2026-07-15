class_name EquipmentData
extends ItemData

enum SlotType {
	HEAD,
	CHEST,
	LEGS,
	FEET,
	HANDS,
	LEFT_HAND,
	RIGHT_HAND,
	AMULET,
	RING,
}

@export var slot_type: SlotType = SlotType.HEAD
@export_range(1, 100, 1) var item_level: int = 1
@export var power_score: int = 0
@export var icon_atlas_index: int = -1
@export var equipment_tags: Array[String] = []
@export var stat_modifiers: Dictionary = {}
@export var stat_multipliers: Dictionary = {}
@export var combat_modifiers: Dictionary = {}
@export var affixes: Array[EquipmentAffixData] = []
@export var set_data: EquipmentSetData
@export_multiline var special_effect_text: String = ""
@export var on_equip_buff: PackedScene


func get_icon_texture() -> Texture2D:
	if icon:
		return icon
	return EquipmentIconCatalog.get_icon_by_index(icon_atlas_index)


func get_combined_stat_modifiers() -> Dictionary:
	var result := stat_modifiers.duplicate(true)
	for affix in affixes:
		if affix:
			_merge_numbers(result, affix.stat_modifiers)
	return result


func get_combined_stat_multipliers() -> Dictionary:
	var result := stat_multipliers.duplicate(true)
	for affix in affixes:
		if affix:
			_merge_numbers(result, affix.stat_multipliers)
	return result


func get_combined_combat_modifiers() -> Dictionary:
	var result := combat_modifiers.duplicate(true)
	for affix in affixes:
		if affix:
			_merge_numbers(result, affix.combat_modifiers)
	return result


func get_effective_power_score() -> int:
	if power_score > 0:
		return power_score
	var score := item_level * 3 + rarity * 12
	for value in get_combined_stat_modifiers().values():
		score += int(absf(float(value)))
	for value in get_combined_stat_multipliers().values():
		score += int(absf(float(value)) * 100.0)
	for value in get_combined_combat_modifiers().values():
		score += int(absf(float(value)) * 100.0)
	return maxi(1, score)


func get_affix_names() -> Array[String]:
	var names: Array[String] = []
	for affix in affixes:
		if affix:
			names.append(affix.display_name)
	return names


static func _merge_numbers(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[key] = float(target.get(key, 0.0)) + float(source[key])
