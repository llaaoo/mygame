class_name EquipmentManager
extends Node
## 装备管理器 — 挂载到 Player 节点，管理装备槽位
##
## 7 个槽位：Head, Chest, Legs, Feet, Hands, LeftHand, RightHand
## equip/unequip 自动调用 BuffManager 施加/移除属性

## 装备变更信号
signal equipment_changed(slot_type: int, equipment: EquipmentData)

## 当前装备映射
var _equipped: Dictionary = {}
var _equipped_buffs: Dictionary = {}

@onready var _buff_manager: BuffManager = $"../BuffManager"


func equip(equipment: EquipmentData) -> bool:
	if not equipment or equipment.slot_type < 0:
		return false

	var slot = equipment.slot_type
	if _equipped.has(slot):
		unequip(slot)

	_equipped[slot] = equipment
	_apply_buff(equipment)

	equipment_changed.emit(slot, equipment)
	print("⚔️ 装备: %s → %s" % [_slot_name(slot), equipment.display_name])
	return true


func unequip(slot: int) -> bool:
	if not _equipped.has(slot):
		return false

	var equipment = _equipped[slot]
	_remove_buff(slot)
	_equipped.erase(slot)

	equipment_changed.emit(slot, null)
	print("🗑️ 卸载: %s → %s" % [_slot_name(slot), equipment.display_name])
	return true


func get_equipment(slot: int) -> EquipmentData:
	return _equipped.get(slot, null)


func _apply_buff(equipment: EquipmentData) -> void:
	if equipment.stat_modifiers.is_empty() and equipment.stat_multipliers.is_empty():
		return
	var buff = Buff.new()
	buff.display_name = equipment.display_name
	buff.icon = equipment.icon
	buff.duration = 0.0
	buff.stat_modifiers = equipment.stat_modifiers.duplicate()
	buff.stat_multipliers = equipment.stat_multipliers.duplicate()
	_buff_manager.apply_buff(buff)
	_equipped_buffs[equipment.slot_type] = buff


func _remove_buff(slot: int) -> void:
	var buff = _equipped_buffs.get(slot)
	if buff:
		_buff_manager.remove_buff(buff)
		_equipped_buffs.erase(slot)


func _slot_name(slot: int) -> String:
	match slot:
		EquipmentData.SlotType.HEAD: return "头部"
		EquipmentData.SlotType.CHEST: return "胸部"
		EquipmentData.SlotType.LEGS: return "腿部"
		EquipmentData.SlotType.FEET: return "足部"
		EquipmentData.SlotType.HANDS: return "手部"
		EquipmentData.SlotType.LEFT_HAND: return "左手"
		EquipmentData.SlotType.RIGHT_HAND: return "右手"
	return "未知"
