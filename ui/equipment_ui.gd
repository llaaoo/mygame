class_name EquipmentUI
extends CanvasLayer
## 装备栏界面 — 7 个槽位面板

@export var equipment_manager: EquipmentManager
@export var inventory_ui: InventoryUI

@onready var _container: HBoxContainer = $Panel/MarginContainer/HBoxContainer

var _slot_nodes: Dictionary = {}  # slot_type → Button

const SLOT_NAMES: Dictionary = {
	0: "头部",
	1: "胸部",
	2: "腿部",
	3: "足部",
	4: "手部",
	5: "左手",
	6: "右手",
}


func _ready() -> void:
	hide()
	_create_slots()


func _create_slots() -> void:
	for slot_type in SLOT_NAMES:
		var vbox = VBoxContainer.new()
		var label = Label.new()
		label.text = SLOT_NAMES[slot_type]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		btn.name = "Slot_%d" % slot_type
		btn.pressed.connect(_on_slot_clicked.bind(slot_type))

		vbox.add_child(label)
		vbox.add_child(btn)
		_container.add_child(vbox)
		_slot_nodes[slot_type] = btn


func set_equipment_manager(em: EquipmentManager) -> void:
	if equipment_manager and equipment_manager.equipment_changed.is_connected(_on_equipment_changed):
		equipment_manager.equipment_changed.disconnect(_on_equipment_changed)
	equipment_manager = em
	if equipment_manager:
		equipment_manager.equipment_changed.connect(_on_equipment_changed)
	_refresh_all()


func open() -> void:
	show()
	_refresh_all()


func close() -> void:
	hide()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func equip_item(equipment: EquipmentData) -> void:
	if equipment_manager:
		equipment_manager.equip(equipment)
	_refresh_slot(equipment.slot_type)


func unequip_to_inventory(slot_type: int) -> void:
	if not equipment_manager:
		return
	var eq = equipment_manager.get_equipment(slot_type)
	if eq and inventory_ui and inventory_ui.inventory:
		inventory_ui.inventory.add_item(eq, 1)
	equipment_manager.unequip(slot_type)


func get_equipment(slot_type: int) -> EquipmentData:
	if equipment_manager:
		return equipment_manager.get_equipment(slot_type)
	return null


func _on_slot_clicked(slot_type: int) -> void:
	if not equipment_manager:
		return
	var eq = equipment_manager.get_equipment(slot_type)
	if eq:
		unequip_to_inventory(slot_type)
		_refresh_all()
		if inventory_ui:
			inventory_ui._refresh_grid()


func _on_equipment_changed(slot_type: int, _equipment: EquipmentData) -> void:
	_refresh_slot(slot_type)


func _refresh_slot(slot_type: int) -> void:
	var btn = _slot_nodes.get(slot_type) as Button
	if not btn or not equipment_manager:
		return
	var eq = equipment_manager.get_equipment(slot_type)
	if eq:
		btn.text = eq.display_name[0]
		btn.tooltip_text = eq.display_name + "\n" + _format_stats(eq)
	else:
		btn.text = ""
		btn.tooltip_text = SLOT_NAMES.get(slot_type, "")


func _refresh_all() -> void:
	for slot_type in _slot_nodes:
		_refresh_slot(slot_type)


func _format_stats(eq: EquipmentData) -> String:
	var lines: Array[String] = []
	for stat in eq.stat_modifiers:
		lines.append("+%s %s" % [eq.stat_modifiers[stat], stat])
	return "\n".join(lines)
