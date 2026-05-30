class_name SkillTreeUI
extends CanvasLayer

var _player: Player = null
var _mastery_manager: SkillMasteryManager = null
var _panel: PanelContainer = null
var _content: HBoxContainer = null
var _level_label: Label = null


func _ready() -> void:
	layer = 135
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_build_ui()


func setup(player: Player) -> void:
	_player = player
	_mastery_manager = player.mastery_manager if player else null
	if not _mastery_manager:
		return
	if not _mastery_manager.mastery_xp_gained.is_connected(_on_mastery_changed):
		_mastery_manager.mastery_xp_gained.connect(_on_mastery_changed)
	if not _mastery_manager.mastery_leveled.is_connected(_on_mastery_leveled):
		_mastery_manager.mastery_leveled.connect(_on_mastery_leveled)
	if not _mastery_manager.character_leveled.is_connected(_on_character_level):
		_mastery_manager.character_leveled.connect(_on_character_level)
	if not _mastery_manager.perk_points_changed.is_connected(_on_perk_points_changed):
		_mastery_manager.perk_points_changed.connect(_on_perk_points_changed)
	if not _mastery_manager.perk_unlocked.is_connected(_on_perk_unlocked):
		_mastery_manager.perk_unlocked.connect(_on_perk_unlocked)
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_M and event.pressed and not event.echo:
		toggle()
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		close()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if not _mastery_manager:
		return
	_set_ui_blocked(true)
	_refresh()
	show()


func close() -> void:
	_set_ui_blocked(false)
	hide()


func _set_ui_blocked(blocked: bool) -> void:
	if _player:
		_player.ui_blocked = blocked


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.06
	_panel.anchor_right = 0.94
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	_panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.96, 6))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Mastery Tree"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_label(title, 22, GameUIStyle.GOLD)
	header.add_child(title)

	_level_label = Label.new()
	GameUIStyle.apply_label(_level_label, 13, GameUIStyle.TEXT_MAIN)
	header.add_child(_level_label)

	var hint := Label.new()
	hint.text = "每个学派每 5 级获得 1 点 perk。触发型连锁效果已转入对应学派树。"
	GameUIStyle.apply_label(hint, 11, GameUIStyle.TEXT_MUTED)
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)


func _refresh() -> void:
	if not _mastery_manager or not _content:
		return
	for child in _content.get_children():
		child.queue_free()
	_level_label.text = "Character Lv.%d" % _mastery_manager.get_character_level()
	for mastery in _mastery_manager.get_all_masteries():
		_content.add_child(_make_school_column(mastery))


func _make_school_column(mastery: SkillMastery) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 420)
	panel.add_theme_stylebox_override("panel", GameUIStyle.slot_style(mastery.level >= 5))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _school_display_name(mastery.school)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(title, 14, GameUIStyle.GOLD)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Lv.%d  |  Points %d" % [mastery.level, mastery.perk_points]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(info, 12, GameUIStyle.TEXT_MAIN)
	vbox.add_child(info)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 8)
	progress.show_percentage = false
	progress.max_value = maxf(1.0, mastery.xp_to_next)
	progress.value = mastery.xp
	progress.add_theme_stylebox_override("background", GameUIStyle.bar_bg())
	progress.add_theme_stylebox_override("fill", GameUIStyle.bar_fill(_school_color(mastery.school)))
	vbox.add_child(progress)

	var xp := Label.new()
	xp.text = "%.0f / %.0f XP" % [mastery.xp, mastery.xp_to_next]
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(xp, 10, GameUIStyle.TEXT_MUTED)
	vbox.add_child(xp)

	for perk in _mastery_manager.get_perks_for_school(mastery.school):
		vbox.add_child(_make_perk_card(perk))

	return panel


func _make_perk_card(perk: SkillPerkData) -> Control:
	var unlocked := _mastery_manager.has_perk(perk.perk_id)
	var can_unlock := _mastery_manager.can_unlock_perk(perk.perk_id)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 78)
	panel.add_theme_stylebox_override("panel", GameUIStyle.slot_style(unlocked))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)

	var title := Label.new()
	title.text = "Lv.%d %s" % [perk.required_level, perk.display_name]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_label(title, 11, GameUIStyle.TEXT_MAIN if unlocked or can_unlock else GameUIStyle.TEXT_MUTED)
	top.add_child(title)

	var state := Label.new()
	state.text = "Unlocked" if unlocked else ("Ready" if can_unlock else "Locked")
	GameUIStyle.apply_label(state, 10, GameUIStyle.GOLD if unlocked or can_unlock else GameUIStyle.TEXT_MUTED)
	top.add_child(state)

	var desc := Label.new()
	desc.text = perk.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(desc, 10, GameUIStyle.TEXT_MUTED if not unlocked else GameUIStyle.TEXT_MAIN)
	vbox.add_child(desc)

	if not unlocked:
		var button := Button.new()
		button.text = "Unlock"
		button.disabled = not can_unlock
		button.pressed.connect(_unlock_perk.bind(perk.perk_id))
		vbox.add_child(button)

	return panel


func _unlock_perk(perk_id: String) -> void:
	if not _mastery_manager:
		return
	if _mastery_manager.unlock_perk(perk_id):
		_refresh()


func _school_display_name(school: int) -> String:
	match school:
		SkillMastery.School.DESTRUCTION:
			return "Destruction"
		SkillMastery.School.CONJURATION:
			return "Conjuration"
		SkillMastery.School.RESTORATION:
			return "Restoration"
		SkillMastery.School.ALTERATION:
			return "Alteration"
		SkillMastery.School.ILLUSION:
			return "Illusion"
		_:
			return "Unknown"


func _school_color(school: int) -> Color:
	match school:
		SkillMastery.School.DESTRUCTION:
			return Color(0.88, 0.32, 0.16, 1.0)
		SkillMastery.School.CONJURATION:
			return Color(0.48, 0.38, 0.78, 1.0)
		SkillMastery.School.RESTORATION:
			return Color(0.86, 0.76, 0.38, 1.0)
		SkillMastery.School.ALTERATION:
			return Color(0.42, 0.68, 0.86, 1.0)
		SkillMastery.School.ILLUSION:
			return Color(0.64, 0.42, 0.72, 1.0)
		_:
			return GameUIStyle.GOLD


func _on_mastery_changed(_skill_id: String, _school: int, _xp_amount: float, _level: int, _progress: float) -> void:
	if visible:
		_refresh()


func _on_mastery_leveled(_skill_id: String, _school: int, _new_level: int) -> void:
	_refresh()


func _on_character_level(_new_level: int) -> void:
	_refresh()


func _on_perk_points_changed(_school: int, _points: int) -> void:
	if visible:
		_refresh()


func _on_perk_unlocked(_school: int, _perk_id: String) -> void:
	if visible:
		_refresh()
