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
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.58)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.90
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
	hint.text = "M closes. Schools advance through use; milestones show current build goals."
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
	panel.custom_minimum_size = Vector2(170, 360)
	panel.add_theme_stylebox_override("panel", GameUIStyle.slot_style(mastery.level >= 5))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = _school_display_name(mastery.school)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(title, 14, GameUIStyle.GOLD)
	vbox.add_child(title)

	var level := Label.new()
	level.text = "Lv.%d" % mastery.level
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(level, 20, GameUIStyle.TEXT_MAIN)
	vbox.add_child(level)

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

	var milestones := [5, 10, 20, 40]
	for milestone in milestones:
		vbox.add_child(_make_milestone(mastery, milestone))

	return panel


func _make_milestone(mastery: SkillMastery, required_level: int) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.add_theme_stylebox_override("panel", GameUIStyle.slot_style(mastery.level >= required_level))

	var label := Label.new()
	label.text = "Lv.%d  %s" % [required_level, _milestone_text(mastery.school, required_level)]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(label, 10, GameUIStyle.TEXT_MAIN if mastery.level >= required_level else GameUIStyle.TEXT_MUTED)
	row.add_child(label)
	return row


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


func _milestone_text(school: int, required_level: int) -> String:
	match school:
		SkillMastery.School.DESTRUCTION:
			return "More reliable damage" if required_level < 20 else "Elemental pressure"
		SkillMastery.School.CONJURATION:
			return "Stronger summons" if required_level < 20 else "Longer command uptime"
		SkillMastery.School.RESTORATION:
			return "Recovery efficiency" if required_level < 20 else "Emergency sustain"
		SkillMastery.School.ALTERATION:
			return "Better protection" if required_level < 20 else "Control resistance"
		SkillMastery.School.ILLUSION:
			return "Mobility control" if required_level < 20 else "Threat redirection"
		_:
			return "Specialization"


func _on_mastery_changed(_skill_id: String, _school: int, _xp_amount: float, _level: int, _progress: float) -> void:
	if visible:
		_refresh()


func _on_mastery_leveled(_skill_id: String, _school: int, _new_level: int) -> void:
	_refresh()


func _on_character_level(_new_level: int) -> void:
	_refresh()
