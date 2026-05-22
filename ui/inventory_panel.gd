class_name InventoryPanel
extends CanvasLayer
## 背包+纸娃娃装备 集成面板 — I 键切换
## 支持拖拽装备/交换 + 富文本悬浮提示

@export var columns: int = 5

var inventory: Inventory
var equipment_manager: EquipmentManager

@onready var _panel: Panel = $Panel
@onready var _background: ColorRect = $Background
@onready var _inv_grid: GridContainer = $Panel/MarginContainer/MainHBox/InventorySection/InvGrid
@onready var _paper_doll: Control = $Panel/MarginContainer/MainHBox/EquipmentSection/PaperDoll

## 纸娃娃按钮映射: slot_type → SlotButton
var _equip_buttons: Dictionary = {}
## 背包格子按钮
var _inv_buttons: Array[SlotButton] = []

## 槽位名称 → 按钮节点名 映射
const SLOT_BUTTON_MAP: Dictionary = {
	EquipmentData.SlotType.HEAD: "HeadSlot",
	EquipmentData.SlotType.CHEST: "ChestSlot",
	EquipmentData.SlotType.HANDS: "HandsSlot",
	EquipmentData.SlotType.LEGS: "LegsSlot",
	EquipmentData.SlotType.FEET: "FeetSlot",
	EquipmentData.SlotType.LEFT_HAND: "LeftHandSlot",
	EquipmentData.SlotType.RIGHT_HAND: "RightHandSlot",
}

const SLOT_NAMES: Dictionary = {
	EquipmentData.SlotType.HEAD: "头部",
	EquipmentData.SlotType.CHEST: "胸部",
	EquipmentData.SlotType.HANDS: "手部",
	EquipmentData.SlotType.LEGS: "腿部",
	EquipmentData.SlotType.FEET: "足部",
	EquipmentData.SlotType.LEFT_HAND: "副手",
	EquipmentData.SlotType.RIGHT_HAND: "主手",
}


func _ready() -> void:
	hide()
	# 确保 GridContainer 配置（编辑器可能未保存）
	_inv_grid.columns = columns
	_inv_grid.add_theme_constant_override("h_separation", 4)
	_inv_grid.add_theme_constant_override("v_separation", 4)
	_setup_equip_buttons()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_I and event.pressed:
		toggle()


func setup(inv: Inventory, em: EquipmentManager) -> void:
	inventory = inv
	equipment_manager = em
	if equipment_manager:
		if equipment_manager.equipment_changed.is_connected(_on_equipment_changed):
			equipment_manager.equipment_changed.disconnect(_on_equipment_changed)
		equipment_manager.equipment_changed.connect(_on_equipment_changed)


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
	var p = get_tree().get_first_node_in_group("player")
	if p: p.set("ui_blocked", blocked)


## ── 初始化：将 .tscn 中的普通 Button 替换为 SlotButton ──

func _setup_equip_buttons() -> void:
	for slot_type in SLOT_BUTTON_MAP:
		var btn_name: String = SLOT_BUTTON_MAP[slot_type]
		var slot_btn := _replace_with_slot_button(btn_name, slot_type)
		if slot_btn:
			_equip_buttons[slot_type] = slot_btn
			slot_btn.slot_dropped.connect(_on_slot_dropped)
			# 保留点击快速装备/卸载
			slot_btn.pressed.connect(_on_equip_clicked.bind(slot_type))


func _replace_with_slot_button(btn_name: String, slot_type: int) -> SlotButton:
	var old = _paper_doll.get_node_or_null(btn_name)
	if not old:
		return null

	var parent = old.get_parent()
	if not parent:
		return null

	# 复制布局属性
	var new_btn := SlotButton.new()
	new_btn.name = btn_name
	new_btn.layout_mode = old.layout_mode
	new_btn.offset_left = old.offset_left
	new_btn.offset_right = old.offset_right
	new_btn.offset_top = old.offset_top
	new_btn.offset_bottom = old.offset_bottom
	new_btn.custom_minimum_size = old.custom_minimum_size

	new_btn.slot_role = SlotButton.SlotRole.EQUIPMENT
	new_btn.slot_id = slot_type
	new_btn.set_empty_placeholder(SLOT_NAMES.get(slot_type, ""))

	old.queue_free()
	parent.add_child(new_btn)
	return new_btn


## ── 刷新全部 ──

func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_equipment()


func _refresh_inventory() -> void:
	# 清除旧按钮
	for btn in _inv_buttons:
		if btn.slot_dropped.is_connected(_on_slot_dropped):
			btn.slot_dropped.disconnect(_on_slot_dropped)
		if btn.pressed.is_connected(_on_inv_clicked):
			btn.pressed.disconnect(_on_inv_clicked)
		btn.queue_free()
	_inv_buttons.clear()

	if not inventory:
		return

	for i in range(inventory.capacity):
		var slot = inventory.get_slot(i)
		var btn := SlotButton.new()
		btn.custom_minimum_size = Vector2(52, 52)
		btn.flat = false
		btn.slot_role = SlotButton.SlotRole.INVENTORY
		btn.slot_id = i

		# 设置物品数据（SlotButton 自动处理图标/文字/品质色/tooltip）
		if slot.item:
			btn.set_item_data(slot.item)
			# 堆叠数量覆盖
			if slot.quantity > 1:
				btn.text = "x%d" % slot.quantity
		else:
			btn.set_item_data(null)

		btn.slot_dropped.connect(_on_slot_dropped)
		btn.pressed.connect(_on_inv_clicked.bind(i))
		_inv_grid.add_child(btn)
		_inv_buttons.append(btn)


func _refresh_equipment() -> void:
	for slot_type in _equip_buttons:
		_refresh_equipment_slot(slot_type)


func _refresh_equipment_slot(slot_type: int) -> void:
	var btn: SlotButton = _equip_buttons.get(slot_type)
	if not btn:
		return

	if equipment_manager:
		var eq = equipment_manager.get_equipment(slot_type)
		if eq:
			btn.set_item_data(eq)
		else:
			btn.set_empty_placeholder(SLOT_NAMES.get(slot_type, ""))
	else:
		btn.set_empty_placeholder(SLOT_NAMES.get(slot_type, ""))


## ── 点击事件（快速装备/卸载，保留给不想拖拽的用户） ──

func _on_inv_clicked(index: int) -> void:
	if not inventory:
		return
	var data = inventory.get_slot(index)
	if not data.item:
		return

	# 装备类型 → 装备
	if data.item is EquipmentData and equipment_manager:
		var eq := data.item as EquipmentData
		var old = equipment_manager.get_equipment(eq.slot_type)
		inventory.remove_item(eq, 1)
		if old:
			inventory.add_item(old, 1)
		equipment_manager.equip(eq)
		_refresh_all()
	else:
		print("📦 选中: %s (非装备)" % data.item.display_name)


func _on_equip_clicked(slot_type: int) -> void:
	if not equipment_manager or not inventory:
		return
	var eq = equipment_manager.get_equipment(slot_type)
	if eq:
		equipment_manager.unequip(slot_type)
		inventory.add_item(eq, 1)
		_refresh_all()


## ── 拖拽事件处理 ──

func _on_slot_dropped(target: SlotButton, data: Dictionary) -> void:
	if not inventory or not equipment_manager:
		return

	var source_role: SlotButton.SlotRole = data["slot_role"]
	var source_id: int = data["slot_id"]
	var source_item: ItemData = data["item"]

	# 情况 1: 背包 → 背包（交换）
	if source_role == SlotButton.SlotRole.INVENTORY and target.slot_role == SlotButton.SlotRole.INVENTORY:
		_swap_inventory_slots(source_id, target.slot_id)

	# 情况 2: 背包 → 装备槽
	elif source_role == SlotButton.SlotRole.INVENTORY and target.slot_role == SlotButton.SlotRole.EQUIPMENT:
		_inventory_to_equip(source_id, target.slot_id)

	# 情况 3: 装备槽 → 背包
	elif source_role == SlotButton.SlotRole.EQUIPMENT and target.slot_role == SlotButton.SlotRole.INVENTORY:
		_equip_to_inventory(source_id, target.slot_id)

	# 情况 4: 装备槽 → 装备槽（交换）
	elif source_role == SlotButton.SlotRole.EQUIPMENT and target.slot_role == SlotButton.SlotRole.EQUIPMENT:
		_swap_equipment_slots(source_id, target.slot_id)


func _swap_inventory_slots(idx_a: int, idx_b: int) -> void:
	if idx_a == idx_b:
		return
	var slot_a = inventory.get_slot(idx_a)
	var slot_b = inventory.get_slot(idx_b)
	inventory.set_slot(idx_a, slot_b.item, slot_b.quantity)
	inventory.set_slot(idx_b, slot_a.item, slot_a.quantity)
	_refresh_all()


func _inventory_to_equip(inv_idx: int, equip_slot: int) -> void:
	var slot = inventory.get_slot(inv_idx)
	if not slot.item or not slot.item is EquipmentData:
		return
	var eq := slot.item as EquipmentData
	if eq.slot_type != equip_slot:
		print("⚠️ 槽位不匹配: %s 需要 %s 槽" % [eq.display_name, SLOT_NAMES.get(eq.slot_type, "?")])
		return

	# 如果目标装备槽已有装备，先卸到背包
	var old = equipment_manager.get_equipment(equip_slot)
	inventory.remove_item(eq, 1)
	if old:
		inventory.add_item(old, 1)
	equipment_manager.equip(eq)
	_refresh_all()


func _equip_to_inventory(equip_slot: int, _inv_idx: int) -> void:
	var eq = equipment_manager.get_equipment(equip_slot)
	if not eq:
		return
	equipment_manager.unequip(equip_slot)
	# add_item 自动寻找可用槽位（堆叠或空格），比强制 set_slot 更安全
	inventory.add_item(eq, 1)
	_refresh_all()


func _swap_equipment_slots(slot_a: int, slot_b: int) -> void:
	if slot_a == slot_b:
		return
	var eq_a = equipment_manager.get_equipment(slot_a)
	var eq_b = equipment_manager.get_equipment(slot_b)

	# 检查类型兼容：A 物品能否放入 B 槽，B 物品能否放入 A 槽
	var can_a_to_b = not eq_a or (eq_a.slot_type == slot_b)
	var can_b_to_a = not eq_b or (eq_b.slot_type == slot_a)

	if not can_a_to_b or not can_b_to_a:
		print("⚠️ 装备槽位类型不匹配，无法直接交换")
		return

	# 卸下双方
	if eq_a:
		equipment_manager.unequip(slot_a)
	if eq_b:
		equipment_manager.unequip(slot_b)

	# 重新装备（equip 根据物品自身 slot_type 放置，因此仅同类型交换有效）
	if eq_a:
		equipment_manager.equip(eq_a)
	if eq_b:
		equipment_manager.equip(eq_b)

	_refresh_all()


## ── 信号回调 ──

func _on_equipment_changed(slot_type: int, _eq: EquipmentData) -> void:
	_refresh_equipment_slot(slot_type)
