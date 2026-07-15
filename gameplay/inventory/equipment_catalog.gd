class_name EquipmentCatalog
extends RefCounted

const EQUIPMENT_DIRECTORY := "res://content/items/equipment"

static var _cache: Array[EquipmentData] = []


static func get_all() -> Array[EquipmentData]:
	if not _cache.is_empty():
		return _cache.duplicate()
	var files := DirAccess.get_files_at(EQUIPMENT_DIRECTORY)
	files.sort()
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var item := load("%s/%s" % [EQUIPMENT_DIRECTORY, file]) as EquipmentData
		if item:
			_cache.append(item)
	return _cache.duplicate()


static func get_by_id(item_id: String) -> EquipmentData:
	for item in get_all():
		if item.id == item_id:
			return item
	return null


static func roll_random(max_rarity: int = 4, min_rarity: int = 0) -> EquipmentData:
	var candidates: Array[EquipmentData] = []
	for item in get_all():
		if item.rarity >= min_rarity and item.rarity <= max_rarity:
			candidates.append(item)
	if candidates.is_empty():
		return null
	# Common items remain common while high-rarity items are still possible.
	var weighted: Array[EquipmentData] = []
	for item in candidates:
		var copies := maxi(1, 6 - item.rarity)
		for _i in range(copies):
			weighted.append(item)
	return weighted.pick_random()


static func clear_cache() -> void:
	_cache.clear()
