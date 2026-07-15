class_name InventoryPanel
extends CanvasLayer

@export var columns: int = 5

var inventory: Inventory
var equipment_manager: EquipmentManager

@onready var _panel: Panel = $Panel
@onready var _background: ColorRect = $Background
@onready var _inv_grid: GridContainer = $Panel/Margin/Main/InventorySection/InvGrid
@onready var _paper_doll: Control = $Panel/Margin/Main/EquipmentSection/PaperDoll
@onready var _summary: Label = $Panel/Margin/Main/EquipmentSection/LoadoutSummary
@onready var _sets: Label = $Panel/Margin/Main/EquipmentSection/SetSummary

var _equip_buttons: Dictionary = {}
var _inv_buttons: Array[SlotButton] = []

const SLOT_BUTTON_MAP := {
	EquipmentData.SlotType.HEAD: "HeadSlot",
	EquipmentData.SlotType.CHEST: "ChestSlot",
	EquipmentData.SlotType.HANDS: "HandsSlot",
	EquipmentData.SlotType.LEGS: "LegsSlot",
	EquipmentData.SlotType.FEET: "FeetSlot",
	EquipmentData.SlotType.LEFT_HAND: "LeftHandSlot",
	EquipmentData.SlotType.RIGHT_HAND: "RightHandSlot",
	EquipmentData.SlotType.AMULET: "AmuletSlot",
	EquipmentData.SlotType.RING: "RingSlot",
}


func _ready() -> void:
	layer = 170
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_inv_grid.columns = columns
	_setup_equip_buttons()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_I and event.pressed and not event.echo:
		toggle()


func setup(inv: Inventory, manager: EquipmentManager) -> void:
	inventory = inv
	equipment_manager = manager
	if equipment_manager and not equipment_manager.loadout_changed.is_connected(_refresh_all):
		equipment_manager.loadout_changed.connect(_refresh_all)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_set_ui_blocked(true)
	_refresh_all()
	show()
	_background.show()


func close() -> void:
	_set_ui_blocked(false)
	hide()
	_background.hide()


func _set_ui_blocked(blocked: bool) -> void:
	get_tree().paused = blocked
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set("ui_blocked", blocked)


func _setup_equip_buttons() -> void:
	for slot_type in SLOT_BUTTON_MAP:
		var old := _paper_doll.get_node_or_null(SLOT_BUTTON_MAP[slot_type]) as Button
		if not old:
			continue
		var button := SlotButton.new()
		button.name = old.name
		button.position = old.position
		button.size = old.size
		button.custom_minimum_size = old.custom_minimum_size
		button.slot_role = SlotButton.SlotRole.EQUIPMENT
		button.slot_id = slot_type
		button.set_empty_placeholder(EquipmentManager.slot_name(slot_type))
		old.get_parent().add_child(button)
		old.queue_free()
		_equip_buttons[slot_type] = button
		button.slot_dropped.connect(_on_slot_dropped)
		button.pressed.connect(_on_equip_clicked.bind(slot_type))


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_equipment()
	_refresh_summary()


func _refresh_inventory() -> void:
	for button in _inv_buttons:
		button.queue_free()
	_inv_buttons.clear()
	if not inventory:
		return
	for index in range(inventory.capacity):
		var slot := inventory.get_slot(index)
		var button := SlotButton.new()
		button.custom_minimum_size = Vector2(54, 54)
		button.slot_role = SlotButton.SlotRole.INVENTORY
		button.slot_id = index
		button.set_item_data(slot.item)
		if slot.item and slot.quantity > 1:
			button.text = "x%d" % slot.quantity
		button.slot_dropped.connect(_on_slot_dropped)
		button.pressed.connect(_on_inv_clicked.bind(index))
		_inv_grid.add_child(button)
		_inv_buttons.append(button)


func _refresh_equipment() -> void:
	for slot_type in _equip_buttons:
		var button: SlotButton = _equip_buttons[slot_type]
		var item := equipment_manager.get_equipment(slot_type) if equipment_manager else null
		if item:
			button.set_item_data(item)
		else:
			button.set_empty_placeholder(EquipmentManager.slot_name(slot_type))


func _refresh_summary() -> void:
	if not equipment_manager:
		_summary.text = "战力 0"
		_sets.text = ""
		return
	var equipped_count := equipment_manager.get_all_equipped().size()
	_summary.text = "装备战力  %d    已装备  %d / %d" % [equipment_manager.get_total_power_score(), equipped_count, SLOT_BUTTON_MAP.size()]
	var lines: Array[String] = []
	for entry in equipment_manager.get_set_summaries():
		var data := entry.data as EquipmentSetData
		lines.append("%s  %d 件" % [entry.name, entry.count])
		for bonus in data.bonuses:
			var marker := "●" if entry.count >= bonus.required_pieces else "○"
			lines.append("  %s %d件：%s" % [marker, bonus.required_pieces, bonus.description])
	_sets.text = "\n".join(lines) if not lines.is_empty() else "尚未组成套装"


func _on_inv_clicked(index: int) -> void:
	if not inventory or not equipment_manager:
		return
	var slot := inventory.get_slot(index)
	if slot.item is EquipmentData:
		_inventory_to_equip(index, (slot.item as EquipmentData).slot_type)


func _on_equip_clicked(slot_type: int) -> void:
	if not inventory or not equipment_manager:
		return
	var item := equipment_manager.get_equipment(slot_type)
	if item and inventory.has_space(item):
		equipment_manager.unequip(slot_type)
		inventory.add_item(item)
		_refresh_all()


func _on_slot_dropped(target: SlotButton, data: Dictionary) -> void:
	if not inventory or not equipment_manager:
		return
	var source_role: SlotButton.SlotRole = data.slot_role
	var source_id: int = data.slot_id
	if source_role == SlotButton.SlotRole.INVENTORY and target.slot_role == SlotButton.SlotRole.INVENTORY:
		_swap_inventory_slots(source_id, target.slot_id)
	elif source_role == SlotButton.SlotRole.INVENTORY and target.slot_role == SlotButton.SlotRole.EQUIPMENT:
		_inventory_to_equip(source_id, target.slot_id)
	elif source_role == SlotButton.SlotRole.EQUIPMENT and target.slot_role == SlotButton.SlotRole.INVENTORY:
		_on_equip_clicked(source_id)


func _swap_inventory_slots(a: int, b: int) -> void:
	if a == b:
		return
	var slot_a := inventory.get_slot(a)
	var slot_b := inventory.get_slot(b)
	inventory.set_slot(a, slot_b.item, slot_b.quantity)
	inventory.set_slot(b, slot_a.item, slot_a.quantity)
	_refresh_all()


func _inventory_to_equip(inventory_index: int, equipment_slot: int) -> void:
	var slot := inventory.get_slot(inventory_index)
	if not slot.item is EquipmentData:
		return
	var item := slot.item as EquipmentData
	if item.slot_type != equipment_slot:
		return
	var old := equipment_manager.get_equipment(equipment_slot)
	inventory.remove_item(item)
	if old:
		inventory.add_item(old)
	equipment_manager.equip(item)
	_refresh_all()
