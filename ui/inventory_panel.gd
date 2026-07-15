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
	layer = GameUIStyle.LAYER_MODAL
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	hide()
	_background.color = GameUIStyle.modal_backdrop()
	_panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.985, 6, GameUIStyle.BORDER_STRONG))
	_inv_grid.columns = columns
	_setup_equip_buttons()
	_apply_theme()
	_add_close_button()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_I:
		if get_tree().paused and not visible:
			return
		toggle()
		get_viewport().set_input_as_handled()


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
	_refresh_all()
	show()
	_background.show()
	GameUIStyle.begin_modal(self)


func close() -> void:
	hide()
	_background.hide()
	GameUIStyle.end_modal(self)


func _apply_theme() -> void:
	var equip_title := _panel.get_node("Margin/Main/EquipmentSection/EquipTitle") as Label
	var inv_title := _panel.get_node("Margin/Main/InventorySection/InvTitle") as Label
	GameUIStyle.apply_title(equip_title, 21)
	GameUIStyle.apply_title(inv_title, 21)
	GameUIStyle.apply_label(_summary, 12, GameUIStyle.TEXT_MAIN)
	GameUIStyle.apply_label(_sets, 11, GameUIStyle.TEXT_MUTED)


func _add_close_button() -> void:
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "×"
	close_button.tooltip_text = "关闭"
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -52
	close_button.offset_top = 12
	close_button.offset_right = -14
	close_button.offset_bottom = 50
	GameUIStyle.apply_button(close_button, GameUIStyle.DANGER)
	close_button.pressed.connect(close)
	_panel.add_child(close_button)


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
