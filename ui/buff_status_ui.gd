class_name BuffStatusUI
extends PanelContainer

var _buff_manager: BuffManager = null
var _list: VBoxContainer = null
var _refresh_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.78, 5))
	custom_minimum_size = Vector2(210, 0)

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
	for child in _list.get_children():
		child.queue_free()

	var entries := _buff_manager.get_active_buff_entries()
	visible = not entries.is_empty()
	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No active effects"
		GameUIStyle.apply_label(empty_label, 11, GameUIStyle.TEXT_MUTED)
		_list.add_child(empty_label)
		return

	for entry in entries:
		_list.add_child(_make_buff_row(entry))


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
	icon_box.visible = icon.texture != null
	icon_box.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var name := Label.new()
	name.text = _format_name(entry)
	GameUIStyle.apply_label(name, 10, GameUIStyle.TEXT_MAIN)
	text_box.add_child(name)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 5)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = entry.get("progress", 1.0)
	bar.add_theme_stylebox_override("background", GameUIStyle.bar_bg())
	bar.add_theme_stylebox_override("fill", GameUIStyle.bar_fill(_color_for_status(entry.get("status_id", ""))))
	text_box.add_child(bar)

	return row


func _format_name(entry: Dictionary) -> String:
	var label: String = entry.get("name", "Effect")
	var stacks: int = entry.get("stacks", 1)
	var remaining: float = entry.get("remaining", 0.0)
	if stacks > 1:
		label += " x%d" % stacks
	if remaining > 0.0:
		label += "  %.0fs" % remaining
	return label


func _color_for_status(status_id: String) -> Color:
	match status_id:
		"burning":
			return Color(0.92, 0.32, 0.14, 1.0)
		"frozen":
			return Color(0.35, 0.72, 0.95, 1.0)
		"poison":
			return Color(0.42, 0.78, 0.28, 1.0)
		"wet":
			return Color(0.28, 0.52, 0.86, 1.0)
		_:
			return GameUIStyle.GOLD
