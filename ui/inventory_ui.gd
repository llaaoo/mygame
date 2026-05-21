class_name InventoryUI
extends CanvasLayer
## 背包界面 — GridContainer 渲染 Inventory 内容

@export var inventory: Inventory
@export var equipment_ui: EquipmentUI
@export var slot_scene: PackedScene

@onready var _grid: GridContainer = $Panel/MarginContainer/GridContainer
@onready var _panel: Panel = $Panel

var _slot_nodes: Array[Control] = []
var _selected_slot: int = -1

const SLOT_COLUMNS: int = 5


func _ready() -> void:
	hide()
	if inventory:
		_refresh_grid()
	_inventory = null  # Will be set externally


func set_inventory(inv: Inventory) -> void:
	inventory = inv
	_refresh_grid()


func open() -> void:
	show()
	_refresh_grid()


func close() -> void:
	hide()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _refresh_grid() -> void:
	for node in _slot_nodes:
		node.queue_free()
	_slot_nodes.clear()

	if not inventory:
		return

	for i in range(inventory.capacity):
		var slot_data = inventory.get_slot(i)
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(48, 48)
		slot_btn.name = "Slot%d" % i

		if slot_data.item:
			slot_btn.text = slot_data.item.display_name[0]
			if slot_data.quantity > 1:
				slot_btn.text += "x%d" % slot_data.quantity
			slot_btn.tooltip_text = slot_data.item.display_name
		else:
			slot_btn.text = ""

		var idx = i
		slot_btn.pressed.connect(_on_slot_clicked.bind(idx))
		_grid.add_child(slot_btn)
		_slot_nodes.append(slot_btn)


func _on_slot_clicked(index: int) -> void:
	if not inventory:
		return

	var slot = inventory.get_slot(index)
	if not slot.item:
		return

	# 如果是装备，尝试装备
	if slot.item is EquipmentData and equipment_ui:
		var eq = slot.item as EquipmentData
		var old = equipment_ui.get_equipment(eq.slot_type)
		inventory.remove_item(eq, 1)
		if old:
			equipment_ui.unequip_to_inventory(eq.slot_type)
		equipment_ui.equip_item(eq)
		_refresh_grid()
	elif slot.item is EquipmentData:
		# 没有 EquipmentUI，只是选中
		_selected_slot = index
		print("选中: %s" % slot.item.display_name)

	_refresh_grid()
