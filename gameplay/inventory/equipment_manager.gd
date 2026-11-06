class_name EquipmentManager
extends Node

signal equipment_changed(slot_type: int, equipment: EquipmentData)
signal loadout_changed
signal set_bonuses_changed

var _equipped: Dictionary = {}
var inventory_store: InventoryService
var actor_id := ""
var _store_loadout: Dictionary={}
var loadout_revision := 0
var _applied_buff: Buff
var _combat_modifiers: Dictionary = {}
var _applied_stat_modifiers: Dictionary = {}
var _set_counts: Dictionary = {}
var _active_set_bonuses: Array[Dictionary] = []

@onready var _buff_manager: BuffManager = $"../BuffManager"


func equip(equipment: EquipmentData) -> bool:
	if inventory_store and equipment:
		var uid:=inventory_store.find_owned(actor_id,equipment.id)
		if uid.is_empty(): return get_equipment(equipment.slot_type)==equipment
		return inventory_store.equip(actor_id,uid).accepted
	if not equipment:
		return false
	var slot := int(equipment.slot_type)
	if _equipped.has(slot):
		_equipped.erase(slot)
	_equipped[slot] = equipment
	_rebuild_loadout_effects()
	equipment_changed.emit(slot, equipment)
	loadout_changed.emit()
	return true


func unequip(slot: int) -> bool:
	if inventory_store: return inventory_store.unequip(actor_id,slot).accepted
	if not _equipped.has(slot):
		return false
	_equipped.erase(slot)
	_rebuild_loadout_effects()
	equipment_changed.emit(slot, null)
	loadout_changed.emit()
	return true


func clear_all() -> void:
	if inventory_store:
		for slot in inventory_store.equipped(actor_id): inventory_store.unequip(actor_id,int(slot))
		return
	var occupied := _equipped.keys()
	_equipped.clear()
	_rebuild_loadout_effects()
	for slot in occupied:
		equipment_changed.emit(slot, null)
	loadout_changed.emit()


func get_equipment(slot: int) -> EquipmentData:
	return _equipped.get(slot, null)


func get_all_equipped() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for slot in _equipped:
		var item := _equipped[slot] as EquipmentData
		if item:
			result.append(item)
	return result


func get_total_power_score() -> int:
	var total := 0
	for item in get_all_equipped():
		total += item.get_effective_power_score()
	return total


func get_modifier_value(key: String) -> float:
	return float(_combat_modifiers.get(key, 0.0))


func get_applied_stat_modifier(key: String) -> float:
	return float(_applied_stat_modifiers.get(key, 0.0))


func get_set_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for set_id in _set_counts:
		var entry: Dictionary = _set_counts[set_id]
		var data := entry.get("data") as EquipmentSetData
		if data:
			result.append({"id": set_id, "name": data.display_name, "count": entry.get("count", 0), "data": data})
	return result


func get_active_set_bonuses() -> Array[Dictionary]:
	return _active_set_bonuses.duplicate(true)


func _rebuild_loadout_effects() -> void:
	loadout_revision += 1
	if _applied_buff and _buff_manager:
		_buff_manager.remove_buff(_applied_buff)
	_applied_buff = null
	_applied_stat_modifiers.clear()
	_combat_modifiers.clear()
	_set_counts.clear()
	_active_set_bonuses.clear()

	var flat: Dictionary = {}
	var percent: Dictionary = {}
	for item in get_all_equipped():
		_merge_numbers(flat, item.get_combined_stat_modifiers())
		_merge_numbers(percent, item.get_combined_stat_multipliers())
		_merge_numbers(_combat_modifiers, item.get_combined_combat_modifiers())
		if item.set_data:
			var set_id := item.set_data.id
			var entry: Dictionary = _set_counts.get(set_id, {"data": item.set_data, "count": 0})
			entry["count"] = int(entry["count"]) + 1
			_set_counts[set_id] = entry

	for set_id in _set_counts:
		var entry: Dictionary = _set_counts[set_id]
		var set_data := entry["data"] as EquipmentSetData
		var count := int(entry["count"])
		for bonus in set_data.get_unlocked_bonuses(count):
			_merge_numbers(flat, bonus.stat_modifiers)
			_merge_numbers(percent, bonus.stat_multipliers)
			_merge_numbers(_combat_modifiers, bonus.combat_modifiers)
			_active_set_bonuses.append({"set": set_data, "count": count, "bonus": bonus})

	if (not flat.is_empty() or not percent.is_empty()) and _buff_manager:
		_applied_stat_modifiers = flat.duplicate(true)
		_applied_buff = Buff.new()
		_applied_buff.buff_id = "equipment_loadout"
		_applied_buff.display_name = "装备负载"
		_applied_buff.persistent = true
		_applied_buff.stat_modifiers = flat
		_applied_buff.stat_multipliers = percent
		_buff_manager.apply_buff(_applied_buff)
	if _buff_manager:
		_buff_manager.reconcile_stack_limits()
	set_bonuses_changed.emit()


func _merge_numbers(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[key] = float(target.get(key, 0.0)) + float(source[key])


static func slot_name(slot: int) -> String:
	match slot:
		EquipmentData.SlotType.HEAD: return "头部"
		EquipmentData.SlotType.CHEST: return "胸部"
		EquipmentData.SlotType.LEGS: return "腿部"
		EquipmentData.SlotType.FEET: return "足部"
		EquipmentData.SlotType.HANDS: return "手部"
		EquipmentData.SlotType.LEFT_HAND: return "副手"
		EquipmentData.SlotType.RIGHT_HAND: return "主手"
		EquipmentData.SlotType.AMULET: return "护符"
		EquipmentData.SlotType.RING: return "戒指"
	return "未知"

func casting_value(key: String) -> float:
	if key not in CastingEquipmentProfile.KEYS:
		return 0.0
	var value := 0.0
	for item in get_all_equipped():
		if item.casting_profile:
			value += float(item.casting_profile.get(key))
	return value

## Capability query also supports a candidate loadout for the equipment comparison UI.
func medium_infusion_cost(candidate: EquipmentData = null) -> int:
	var items := get_all_equipped()
	if candidate:
		items = items.filter(func(item: EquipmentData): return item.slot_type != candidate.slot_type)
		items.append(candidate)
	var cost := -1
	for item in items:
		if item.casting_profile and item.casting_profile.medium_infusion:
			var value: int = item.casting_profile.medium_infusion_cost
			cost = value if cost < 0 else mini(cost, value)
	return cost

func partial_boon_cost(candidate: EquipmentData = null) -> int:
	var items := get_all_equipped()
	if candidate:
		items = items.filter(func(item: EquipmentData): return item.slot_type != candidate.slot_type)
		items.append(candidate)
	var cost := -1
	for item in items:
		if item.casting_profile and item.casting_profile.partial_boon_consumption:
			var value: int = item.casting_profile.partial_boon_mana_cost
			cost = value if cost < 0 else mini(cost, value)
	return cost

func bind_inventory(store: InventoryService,id: String) -> void:
	if inventory_store and inventory_store.changed.is_connected(_refresh_from_store): inventory_store.changed.disconnect(_refresh_from_store)
	inventory_store=store
	actor_id=id
	_store_loadout={"initial":""}
	inventory_store.changed.connect(_refresh_from_store)
	_refresh_from_store()
func _refresh_from_store() -> void:
	var worn:=inventory_store.equipped(actor_id)
	if worn==_store_loadout: return
	_store_loadout=worn
	_equipped.clear()
	for slot in worn:
		var instance:=inventory_store.item(worn[slot])
		if instance: _equipped[int(slot)]=inventory_store.definitions.get(instance.definition_id)
	_rebuild_loadout_effects()
	loadout_changed.emit()
func _exit_tree() -> void:
	if inventory_store and inventory_store.changed.is_connected(_refresh_from_store): inventory_store.changed.disconnect(_refresh_from_store)
