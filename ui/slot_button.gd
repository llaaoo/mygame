class_name SlotButton
extends Button
## 通用槽位按钮 — 支持拖拽 (drag-and-drop) + 富文本提示 (tooltip)
##
## 用于背包格子和纸娃娃装备槽

## 槽位角色
enum SlotRole { INVENTORY, EQUIPMENT }

signal slot_dropped(target: SlotButton, data: Dictionary)

## 槽位角色 (库存/装备)
var slot_role: SlotRole = SlotRole.INVENTORY
## 槽位 ID：背包索引 (0-19) 或装备槽类型 (EquipmentData.SlotType)
var slot_id: int = -1

## 当前物品数据
var item_data: ItemData = null

## 品质颜色映射
const RARITY_COLORS: Array[Color] = [
	Color.WHITE,           # 0: 普通
	Color(0.3, 0.5, 1.0),  # 1: 稀有 (蓝)
	Color(0.7, 0.2, 1.0),  # 2: 史诗 (紫)
	Color(1.0, 0.65, 0.0), # 3: 传说 (橙)
]

## 品质名称
const RARITY_NAMES: Array[String] = ["普通", "稀有", "史诗", "传说"]


func set_item_data(data: ItemData) -> void:
	item_data = data
	if data:
		# 设置 tooltip_text 触发 Godot 内置 tooltip 系统
		tooltip_text = " "
		# 视觉更新
		var rarity = clampi(data.rarity, 0, 3)
		modulate = RARITY_COLORS[rarity]
		if data.icon:
			icon = data.icon
			expand_icon = true
			text = ""
		else:
			icon = null
			text = data.display_name[0]
	else:
		tooltip_text = ""
		icon = null
		text = ""
		modulate = Color.WHITE


func set_empty_placeholder(txt: String) -> void:
	item_data = null
	tooltip_text = ""
	icon = null
	text = txt
	modulate = Color.WHITE


## ── 自定义富文本 Tooltip ──

func _make_custom_tooltip(_for_text: String) -> Control:
	if item_data == null:
		return null

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _create_tooltip_stylebox())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# 物品名称（品质色）
	var name_label := Label.new()
	name_label.text = item_data.display_name
	var rarity = clampi(item_data.rarity, 0, 3)
	name_label.add_theme_color_override("font_color", RARITY_COLORS[rarity])
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# 品质标签（非普通时显示）
	if rarity > 0:
		var rarity_label := Label.new()
		rarity_label.text = "⭐ " + RARITY_NAMES[rarity]
		rarity_label.add_theme_color_override("font_color", RARITY_COLORS[rarity])
		rarity_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(rarity_label)

	# 装备属性
	if item_data is EquipmentData:
		var eq := item_data as EquipmentData
		var stats_text := _format_stats(eq)
		if stats_text:
			var stats_label := Label.new()
			stats_label.text = stats_text
			stats_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			stats_label.add_theme_font_size_override("font_size", 13)
			vbox.add_child(stats_label)

	# 描述
	if not item_data.description.is_empty():
		var desc_label := Label.new()
		desc_label.text = item_data.description
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(200, 0)
		vbox.add_child(desc_label)

	# 操作提示
	var hint_label := Label.new()
	hint_label.text = "拖拽以移动/装备"
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hint_label)

	return panel


func _format_stats(eq: EquipmentData) -> String:
	var lines: Array[String] = []
	for s in eq.stat_modifiers:
		lines.append("+%s %s" % [eq.stat_modifiers[s], s])
	for s in eq.stat_multipliers:
		lines.append("+%d%% %s" % [eq.stat_multipliers[s] * 100, s])
	return "\n".join(lines)


func _create_tooltip_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.3, 0.4, 1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


## ── 拖拽系统 ──

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_data == null:
		return null

	# 幽灵效果：拖动中的源槽位半透明
	modulate.a = 0.3

	# 创建拖动预览
	var preview := Label.new()
	preview.text = text if not icon else ""
	if icon:
		# Label 不支持 icon，创建简化预览
		preview.text = item_data.display_name[0]
	preview.add_theme_font_size_override("font_size", 18)
	preview.add_theme_color_override("font_color", RARITY_COLORS[clampi(item_data.rarity, 0, 3)])
	preview.custom_minimum_size = Vector2(52, 52)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	set_drag_preview(preview)

	return {
		"slot_id": slot_id,
		"slot_role": slot_role,
		"item": item_data,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item") and data["item"] != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	slot_dropped.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# 拖拽结束，恢复透明度
		if item_data:
			modulate.a = 1.0
