class_name InventoryPanel
extends CanvasLayer
## 背包+纸娃娃装备 集成面板 — I 键切换

@export var columns: int = 5

var inventory: Inventory
var equipment_manager: EquipmentManager

@onready var _panel: Panel = $Panel
@onready var _background: ColorRect = $Background
@onready var _inv_grid: GridContainer = $Panel/MarginContainer/MainHBox/InventorySection/InvGrid
@onready var _paper_doll: Control = $Panel/MarginContainer/MainHBox/EquipmentSection/PaperDoll

## 纸娃娃按钮映射: slot_type → Button
var _equip_buttons: Dictionary = {}
## 背包格子按钮
var _inv_buttons: Array[Button] = []

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
	_refresh_all()
	show()
	_background.show()


func close() -> void:
	hide()
	_background.hide()


## 连接纸娃娃按钮
func _setup_equip_buttons() -> void:
	for slot_type in SLOT_BUTTON_MAP:
		var btn_name = SLOT_BUTTON_MAP[slot_type]
		var btn = _paper_doll.get_node_or_null(btn_name) as Button
		if btn:
			_equip_buttons[slot_type] = btn
			var st = slot_type
			if btn.pressed.is_connected(_on_equip_clicked):
				btn.pressed.disconnect(_on_equip_clicked)
			btn.pressed.connect(_on_equip_clicked.bind(st))


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_equipment()


func _refresh_inventory() -> void:
	for btn in _inv_buttons:
		btn.queue_free()
	_inv_buttons.clear()

	if not inventory:
		return

	for i in range(inventory.capacity):
		var data = inventory.get_slot(i)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(52, 52)
		btn.flat = false

		if data.item:
			# 根据品质着色
			var rarity_colors = [
				Color.WHITE,           # 0: 普通
				Color(0.3, 0.5, 1.0),  # 1: 稀有 (蓝)
				Color(0.7, 0.2, 1.0),  # 2: 史诗 (紫)
				Color(1.0, 0.65, 0.0), # 3: 传说 (橙)
			]
			var rarity = clampi(data.item.rarity, 0, 3)

			# 显示图标或首字
			if data.item.icon:
				btn.icon = data.item.icon
				btn.expand_icon = true
			else:
				btn.text = data.item.display_name[0]

			# 堆叠数量
			if data.quantity > 1:
				btn.text = "x%d" % data.quantity

			btn.tooltip_text = "%s\n%s" % [data.item.display_name, data.item.description]
			btn.modulate = rarity_colors[rarity]
		else:
			btn.text = ""

		var idx = i
		btn.pressed.connect(_on_inv_clicked.bind(idx))
		_inv_grid.add_child(btn)
		_inv_buttons.append(btn)


func _on_inv_clicked(index: int) -> void:
	if not inventory:
		return
	var data = inventory.get_slot(index)
	if not data.item:
		return

	# 装备类型 → 装备
	if data.item is EquipmentData and equipment_manager:
		var eq = data.item as EquipmentData
		# 先卸下旧装备
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


func _on_equipment_changed(slot_type: int, _eq: EquipmentData) -> void:
	_refresh_equipment_slot(slot_type)


func _refresh_equipment() -> void:
	for slot_type in _equip_buttons:
		_refresh_equipment_slot(slot_type)


func _refresh_equipment_slot(slot_type: int) -> void:
	var btn = _equip_buttons.get(slot_type) as Button
	if not btn:
		return

	if equipment_manager:
		var eq = equipment_manager.get_equipment(slot_type)
		if eq:
			if eq.icon:
				btn.icon = eq.icon
				btn.expand_icon = true
				btn.text = ""
			else:
				btn.icon = null
				btn.text = eq.display_name[0]
			btn.tooltip_text = eq.display_name + "\n" + _format_stats(eq)
		else:
			btn.icon = null
			btn.text = SLOT_NAMES.get(slot_type, "")
			btn.tooltip_text = SLOT_NAMES.get(slot_type, "")
	else:
		btn.icon = null
		btn.text = SLOT_NAMES.get(slot_type, "")


func _format_stats(eq: EquipmentData) -> String:
	var lines: Array[String] = []
	for s in eq.stat_modifiers:
		lines.append("+%s %s" % [eq.stat_modifiers[s], s])
	for s in eq.stat_multipliers:
		lines.append("+%d%% %s" % [eq.stat_multipliers[s] * 100, s])
	return "\n".join(lines) if lines else "无属性"
