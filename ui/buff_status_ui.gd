class_name BuffStatusUI
extends PanelContainer

var _buff_manager: BuffManager = null
var _list: VBoxContainer = null
var _rows: Dictionary = {}
var _refresh_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.88, 5))
	custom_minimum_size = Vector2(214, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	margin.add_child(_list)


func setup(player: Player) -> void:
	if not player:
		return
	_buff_manager = player.get_node_or_null("BuffManager") as BuffManager
	if not _buff_manager:
		return
	if _buff_manager.buffs_changed.is_connected(_refresh):
		_buff_manager.buffs_changed.disconnect(_refresh)
	_buff_manager.buffs_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if not _buff_manager:
		return
	_refresh_accum += delta
	if _refresh_accum >= 0.2:
		_refresh_accum = 0.0
		_refresh()


func _refresh() -> void:
	if not _list or not _buff_manager:
		return
	var entries := _buff_manager.get_active_buff_entries().filter(func(entry): return entry.id != "equipment_loadout")
	visible = not entries.is_empty()
	var seen: Dictionary = {}
	for entry in entries:
		var id: int = entry.instance_id
		seen[id] = true
		if not _rows.has(id):
			_rows[id] = _make_buff_row(entry)
			_list.add_child(_rows[id])
		var row: Control = _rows[id]
		(row.get_meta("name_label") as Label).text = _format_name(entry)
		(row.get_meta("timer_bar") as ProgressBar).value = entry.progress
		row.tooltip_text = "%s\n%s\n来源：%s" % [["增益", "异常", "持续伤害", "控制", "光环"][entry.category], entry.description, str(entry.source)]
	for id in _rows.keys():
		if not seen.has(id):
			var row: Control = _rows[id]
			_list.remove_child(row)
			row.queue_free()
			_rows.erase(id)


func _make_buff_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(190, 24)
	row.add_theme_constant_override("separation", 7)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(20, 20)
	icon_box.add_theme_stylebox_override("panel", GameUIStyle.slot_style(entry.get("stacks", 1) > 1))
	row.add_child(icon_box)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = entry.get("icon", null)
	icon.modulate = Color.WHITE if icon.texture else Color(1, 1, 1, 0.12)
	icon_box.visible = true
	icon_box.add_child(icon)
	if not icon.texture:
		var glyph := Label.new()
		glyph.text = "◇"
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		GameUIStyle.apply_label(glyph, 17, _color_for_status(entry.get("status_id", "")))
		icon_box.add_child(glyph)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var name := Label.new()
	name.text = _format_name(entry)
	GameUIStyle.apply_label(name, 12, GameUIStyle.TEXT_MAIN)
	text_box.add_child(name)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 5)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = entry.get("progress", 1.0)
	bar.add_theme_stylebox_override("background", GameUIStyle.bar_bg())
	bar.add_theme_stylebox_override("fill", GameUIStyle.bar_fill(_color_for_status(entry.get("status_id", ""))))
	text_box.add_child(bar)

	row.set_meta("name_label", name)
	row.set_meta("timer_bar", bar)
	return row


func _format_name(entry: Dictionary) -> String:
	var label: String = entry.get("name", "Effect")
	var stacks: int = entry.get("stacks", 1)
	var remaining: float = entry.get("remaining", 0.0)
	if int(entry.get("capacity", 1)) > 1:
		label += " %d/%d" % [stacks, int(entry.capacity)]
	if remaining > 0.0:
		label += "  %.1fs" % remaining
	return label


func _color_for_status(status_id: String) -> Color:
	return ElementVisuals.status_color(status_id)
