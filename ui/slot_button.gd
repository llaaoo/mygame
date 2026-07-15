class_name SlotButton
extends Button

enum SlotRole { INVENTORY, EQUIPMENT }

signal slot_dropped(target: SlotButton, data: Dictionary)

var slot_role: SlotRole = SlotRole.INVENTORY
var slot_id: int = -1
var item_data: ItemData

const RARITY_COLORS: Array[Color] = [
	Color(0.72, 0.76, 0.8),
	Color(0.25, 0.72, 0.42),
	Color(0.25, 0.55, 1.0),
	Color(0.72, 0.3, 0.95),
	Color(1.0, 0.62, 0.12),
]
const RARITY_NAMES: Array[String] = ["普通", "精良", "稀有", "史诗", "传说"]
const STAT_NAMES := {
	"max_hp": "最大生命",
	"max_mana": "最大魔能",
	"attack_damage": "近战伤害",
	"move_speed": "移动速度",
}
const COMBAT_NAMES := {
	"damage.all": "全部法术伤害",
	"damage.fire": "火焰伤害",
	"damage.ice": "寒冰伤害",
	"damage.lightning": "闪电伤害",
	"damage.poison": "毒素伤害",
	"damage.shadow": "暗影伤害",
	"damage.summon": "召唤伤害",
	"cooldown.all": "全局冷却",
	"mana_cost.all": "魔能消耗",
	"damage_reduction": "伤害减免",
	"healing_received": "受到的治疗",
	"crit_chance": "暴击率",
	"crit_damage": "暴击伤害",
}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_rarity_style(0)


func set_item_data(data: ItemData) -> void:
	item_data = data
	if not data:
		set_empty_placeholder("")
		return
	tooltip_text = " "
	var display_icon := data.icon
	if data is EquipmentData:
		display_icon = (data as EquipmentData).get_icon_texture()
	icon = display_icon
	expand_icon = display_icon != null
	text = "" if display_icon else data.display_name.left(1)
	_apply_rarity_style(data.rarity)


func set_empty_placeholder(txt: String) -> void:
	item_data = null
	tooltip_text = ""
	icon = null
	text = txt
	_apply_rarity_style(0, true)


static func get_rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


func _apply_rarity_style(rarity: int, empty: bool = false) -> void:
	var color := get_rarity_color(rarity)
	var normal := _slot_style(Color(0.075, 0.085, 0.1, 0.97), color if not empty else Color(0.24, 0.27, 0.32))
	var hover := _slot_style(Color(0.12, 0.14, 0.17, 1.0), color.lightened(0.18))
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_color_override("font_color", Color(0.72, 0.75, 0.8) if empty else color)


func _make_custom_tooltip(_for_text: String) -> Control:
	if not item_data:
		return null
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _tooltip_style())
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(280, 0)
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var rarity := clampi(item_data.rarity, 0, RARITY_NAMES.size() - 1)
	_add_label(vbox, item_data.display_name, 17, get_rarity_color(rarity))
	_add_label(vbox, RARITY_NAMES[rarity], 11, get_rarity_color(rarity).darkened(0.05))

	if item_data is EquipmentData:
		var eq := item_data as EquipmentData
		_add_label(vbox, "%s  |  物品等级 %d  |  战力 %d" % [EquipmentManager.slot_name(eq.slot_type), eq.item_level, eq.get_effective_power_score()], 11, Color(0.62, 0.67, 0.74))
		_add_separator(vbox)
		for line in _equipment_stat_lines(eq):
			_add_label(vbox, line, 12, Color(0.4, 0.92, 0.58))
		if eq.set_data:
			_add_label(vbox, "套装：%s" % eq.set_data.display_name, 12, eq.set_data.theme_color)
		for affix_name in eq.get_affix_names():
			_add_label(vbox, "◆ %s" % affix_name, 11, Color(0.62, 0.78, 1.0))
		if not eq.special_effect_text.is_empty():
			_add_label(vbox, eq.special_effect_text, 11, Color(1.0, 0.76, 0.32), true)

	if not item_data.description.is_empty():
		_add_separator(vbox)
		_add_label(vbox, item_data.description, 11, Color(0.68, 0.7, 0.74), true)
	return panel


func _equipment_stat_lines(eq: EquipmentData) -> Array[String]:
	var lines: Array[String] = []
	for stat in eq.get_combined_stat_modifiers():
		var value := float(eq.get_combined_stat_modifiers()[stat])
		lines.append("%s%g %s" % ["+" if value >= 0 else "", value, STAT_NAMES.get(stat, stat)])
	for stat in eq.get_combined_stat_multipliers():
		var value := float(eq.get_combined_stat_multipliers()[stat]) * 100.0
		lines.append("%s%g%% %s" % ["+" if value >= 0 else "", value, STAT_NAMES.get(stat, stat)])
	for key in eq.get_combined_combat_modifiers():
		var value := float(eq.get_combined_combat_modifiers()[key]) * 100.0
		lines.append("%s%g%% %s" % ["+" if value >= 0 else "", value, COMBAT_NAMES.get(key, key)])
	return lines


func _add_label(parent: Control, value: String, size: int, color: Color, wrap: bool = false) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _add_separator(parent: Control) -> void:
	var separator := HSeparator.new()
	separator.modulate = Color(0.4, 0.43, 0.5, 0.45)
	parent.add_child(separator)


func _slot_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.052, 0.98)
	style.border_color = get_rarity_color(item_data.rarity).darkened(0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item_data:
		return null
	modulate.a = 0.35
	var preview := TextureRect.new()
	preview.texture = icon
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.custom_minimum_size = Vector2(52, 52)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"slot_id": slot_id, "slot_role": slot_role, "item": item_data}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item") and data["item"] != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	slot_dropped.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
