class_name GrayriverItems
extends RefCounted
const CHARACTER_IDS := ["guard","hunter","caster","bridge_keeper","mine_quartermaster","prison_veteran"]
const EQUIPMENT_IDS := ["river_sabre","river_spear","river_staff","river_coat","river_boots","river_shield","river_foreman_coat","river_survey_spear","river_oath_blade"]

static func equipment() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for id in EQUIPMENT_IDS: result.append(load("res://content/frontier/equipment/%s.tres" % id) as EquipmentData)
	return result
