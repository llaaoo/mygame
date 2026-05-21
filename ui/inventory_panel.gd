class_name InventoryPanel
extends CanvasLayer
## 背包+装备栏 集成面板 — Tab 键开关

@export var columns: int = 5

var inventory: Inventory
var equipment_manager: EquipmentManager

@onready var _panel: Panel = $Panel
@onready var _inv_grid: GridContainer = $Panel/VBoxContainer/InvGrid
@onready var _equip_hbox: HBoxContainer = $Panel/VBoxContainer/EquipHBox

var _inv_slots: Array[Button] = []
var _equip_slots: Dictionary = {}

const SLOT_NAMES: Dictionary = {
	0: "头", 1: "胸", 2: "腿", 3: "足", 4: "手", 5: "副", 6: "主",
}


func _ready() -> void:
	hide()
	_create_equip_slots()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed:
		toggle()


func setup(inv: Inventory, em: EquipmentManager) -> void:
	inventory = inv
	equipment_manager = em
	if equipment_manager:
		equipment_manager.equipment_changed.connect(_on_equipment_changed)


func toggle() -> void:
	if visible:
		hide()
	else:
		open()


func open() -> void:
	_refresh_all()
	show()


func close() -> void:
	hide()


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_equipment()


func _refresh_inventory() -> void:
	for btn in _inv_slots:
		btn.queue_free()
	_inv_slots.clear()
	if not inventory:
		return

	for i in range(inventory.capacity):
		var data = inventory.get_slot(i)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		if data.item:
			btn.text = data.item.display_name[0]
			btn.tooltip_text = "%s\n%s" % [data.item.display_name, data.item.description]
			if data.quantity > 1:
				btn.text += str(data.quantity)
		var idx = i
		btn.pressed.connect(_on_inv_clicked.bind(idx))
		_inv_grid.add_child(btn)
		_inv_slots.append(btn)


func _on_inv_clicked(index: int) -> void:
	if not inventory:
		return
	var data = inventory.get_slot(index)
	if not data.item:
		return

	# 装备类型 → 尝试装备
	if data.item is EquipmentData and equipment_manager:
		var eq = data.item as EquipmentData
		var old = equipment_manager.get_equipment(eq.slot_type)
		inventory.remove_item(eq, 1)
		if old:
			inventory.add_item(old, 1)
		equipment_manager.equip(eq)
		_refresh_all()


func _create_equip_slots() -> void:
	for st in range(7):
		var vbox = VBoxContainer.new()
		var lbl = Label.new()
		lbl.text = SLOT_NAMES[st]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(52, 52)
		var slot = st
		btn.pressed.connect(_on_equip_clicked.bind(slot))
		vbox.add_child(lbl)
		vbox.add_child(btn)
		_equip_hbox.add_child(vbox)
		_equip_slots[st] = btn


func _refresh_equipment() -> void:
	for st in _equip_slots:
		var btn = _equip_slots[st] as Button
		if equipment_manager:
			var eq = equipment_manager.get_equipment(st)
			if eq:
				btn.text = eq.display_name[0]
				btn.tooltip_text = eq.display_name + "\n" + _format_stats(eq)
			else:
				btn.text = ""
				btn.tooltip_text = SLOT_NAMES[st]
		else:
			btn.text = ""


func _on_equip_clicked(slot_type: int) -> void:
	if not equipment_manager or not inventory:
		return
	var eq = equipment_manager.get_equipment(slot_type)
	if eq:
		equipment_manager.unequip(slot_type)
		inventory.add_item(eq, 1)
		_refresh_all()


func _on_equipment_changed(_slot: int, _eq: EquipmentData) -> void:
	_refresh_equipment()


func _format_stats(eq: EquipmentData) -> String:
	var lines: Array[String] = []
	for s in eq.stat_modifiers:
		lines.append("+%s %s" % [eq.stat_modifiers[s], s])
	return "\n".join(lines)
