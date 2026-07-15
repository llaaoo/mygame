class_name EquipmentSetData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var theme_color: Color = Color.WHITE
@export var bonuses: Array[EquipmentSetBonus] = []


func get_unlocked_bonuses(piece_count: int) -> Array[EquipmentSetBonus]:
	var result: Array[EquipmentSetBonus] = []
	for bonus in bonuses:
		if bonus and piece_count >= bonus.required_pieces:
			result.append(bonus)
	return result
