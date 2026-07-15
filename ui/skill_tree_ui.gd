class_name SkillTreeUI
extends CanvasLayer

var _player: Player = null
var _mastery_manager: SkillMasteryManager = null
var _panel: PanelContainer = null
var _content: HBoxContainer = null
var _level_label: Label = null


func _ready() -> void:
	layer = GameUIStyle.LAYER_MODAL
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
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
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if visible and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_M:
		if get_tree().paused and not visible:
			return
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if not _mastery_manager:
		return
	_refresh()
	show()
	GameUIStyle.begin_modal(self)


func close() -> void:
	hide()
	GameUIStyle.end_modal(self)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = GameUIStyle.modal_backdrop()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.035
	_panel.anchor_right = 0.965
	_panel.anchor_top = 0.055
	_panel.anchor_bottom = 0.945
	_panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.985, 6, GameUIStyle.BORDER_STRONG))
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
	title.text = "法术精通树"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_label(title, 22, GameUIStyle.GOLD)
	header.add_child(title)

	_level_label = Label.new()
	GameUIStyle.apply_label(_level_label, 13, GameUIStyle.TEXT_MAIN)
	header.add_child(_level_label)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "关闭"
	close_button.custom_minimum_size = Vector2(38, 38)
	GameUIStyle.apply_button(close_button, GameUIStyle.DANGER)
	close_button.pressed.connect(close)
	header.add_child(close_button)

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
	_level_label.text = "角色 Lv.%d" % _mastery_manager.get_character_level()
	for mastery in _mastery_manager.get_all_masteries():
		_content.add_child(_make_school_column(mastery))


func _make_school_column(mastery: SkillMastery) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(198, 0)
	panel.add_theme_stylebox_override("panel", GameUIStyle.slot_style(mastery.level >= 5))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	var tree_data := _mastery_manager.get_tree_data(mastery.school)
	title.text = tree_data.display_name if tree_data else _school_display_name(mastery.school)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(title, 14, GameUIStyle.GOLD)
	vbox.add_child(title)

	var info := Label.new()
	info.text = "Lv.%d  |  节点点数 %d" % [mastery.level, mastery.perk_points]
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

	var spell_header := Label.new()
	spell_header.text = "法术目录"
	GameUIStyle.apply_label(spell_header, 11, GameUIStyle.GOLD)
	vbox.add_child(spell_header)
	for skill in _mastery_manager.get_spells_for_school(mastery.school):
		vbox.add_child(_make_spell_row(skill))

	var perk_header := Label.new()
	perk_header.text = "精通节点"
	GameUIStyle.apply_label(perk_header, 11, GameUIStyle.GOLD)
	vbox.add_child(perk_header)

	for perk in _mastery_manager.get_perks_for_school(mastery.school):
		vbox.add_child(_make_perk_card(perk))

	return panel


func _make_spell_row(skill: SkillData) -> Control:
	var unlocked := _mastery_manager.is_spell_unlocked(skill)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = SkillIconCatalog.get_icon(skill)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if unlocked else Color(0.38, 0.4, 0.45, 0.75)
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = skill.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameUIStyle.apply_label(name_label, 10, GameUIStyle.TEXT_MAIN if unlocked else GameUIStyle.TEXT_MUTED)
	row.add_child(name_label)
	var level_label := Label.new()
	level_label.text = "T%d / Lv.%d" % [skill.tier, _mastery_manager.get_spell_unlock_level(skill)]
	GameUIStyle.apply_label(level_label, 9, GameUIStyle.GOLD if unlocked else GameUIStyle.TEXT_MUTED)
	row.add_child(level_label)
	row.tooltip_text = "%s\n%s\n%s" % [skill.description, skill.mechanics, skill.role]
	return row


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
	state.text = "已激活" if unlocked else ("可激活" if can_unlock else "未解锁")
	GameUIStyle.apply_label(state, 10, GameUIStyle.GOLD if unlocked or can_unlock else GameUIStyle.TEXT_MUTED)
	top.add_child(state)

	var desc := Label.new()
	desc.text = perk.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(desc, 10, GameUIStyle.TEXT_MUTED if not unlocked else GameUIStyle.TEXT_MAIN)
	vbox.add_child(desc)

	if not unlocked:
		var button := Button.new()
		button.text = "激活节点"
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
			return "毁灭学派"
		SkillMastery.School.CONJURATION:
			return "召唤学派"
		SkillMastery.School.RESTORATION:
			return "恢复学派"
		SkillMastery.School.ALTERATION:
			return "变化学派"
		SkillMastery.School.ILLUSION:
			return "幻术学派"
		_:
			return "未知学派"


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
