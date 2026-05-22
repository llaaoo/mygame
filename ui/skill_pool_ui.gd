class_name SkillPoolUI
extends CanvasLayer
## 技能池 — K 键。左手/右手 + 4 快捷键槽位

var _skill_pool: SkillPool = null
var _skill_manager: SkillManager = null
var _selected_skill: SkillData = null

var _background: ColorRect = null
var _panel: Panel = null
var _skill_grid: GridContainer = null
var _equip_slots: Array[PanelContainer] = []
var _equip_sources: Array[String] = []  ## "left","right","slot_0",...
var _hint_label: Label = null


func _ready() -> void:
	hide()
	_build_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_K and event.pressed:
		toggle()


func setup(pool: SkillPool, sm: SkillManager) -> void:
	_skill_pool = pool
	_skill_manager = sm
	sm.hand_changed.connect(_on_hand_changed)
	sm.slot_changed.connect(_on_slot_changed)


func toggle() -> void:
	if visible: close()
	else: open()


func open() -> void:
	_set_ui_blocked(true)
	_refresh_all()
	show()


func close() -> void:
	_set_ui_blocked(false)
	_selected_skill = null
	hide()


func _set_ui_blocked(blocked: bool) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p: p.set("ui_blocked", blocked)


func _build_ui() -> void:
	_background = ColorRect.new()
	_background.color = Color(0, 0, 0, 0.6)
	_background.anchor_right = 1.0
	_background.anchor_bottom = 1.0
	add_child(_background)

	_panel = Panel.new()
	_panel.anchor_left = 0.15; _panel.anchor_right = 0.85
	_panel.anchor_top = 0.1; _panel.anchor_bottom = 0.9
	_panel.add_theme_stylebox_override("panel", _make_panel_bg())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0; margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	margin.add_child(main_hbox)

	# ── 左侧：技能网格 ──
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_vbox)

	var title := Label.new()
	title.text = "📖 技能池"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	left_vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	_skill_grid = GridContainer.new()
	_skill_grid.columns = 4
	_skill_grid.add_theme_constant_override("h_separation", 8)
	_skill_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_skill_grid)

	_hint_label = Label.new()
	_hint_label.text = "选技能 → 左键槽位装备 | 右键槽位卸载 | K 关闭"
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_vbox.add_child(_hint_label)

	# ── 右侧：双手 + 快捷键槽 ──
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(right_vbox)

	right_vbox.add_child(_make_section_label("🖐️ 双手"))
	_add_equip_slot(right_vbox, "left", "左手")
	_add_equip_slot(right_vbox, "right", "右手")

	right_vbox.add_child(_make_section_label("⌨️ 快捷键"))
	for i in range(4):
		_add_equip_slot(right_vbox, "slot_%d" % i, "键 %d" % (i + 1))


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	return lbl


func _add_equip_slot(parent: Control, source: String, label: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 40)
	panel.add_theme_stylebox_override("panel", _make_slot_bg())
	parent.add_child(panel)
	_equip_slots.append(panel)
	_equip_sources.append(source)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.name = "Sub"
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	sub_lbl.text = label
	info.add_child(sub_lbl)

	panel.gui_input.connect(_on_slot_clicked.bind(source))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_slot_clicked(event: InputEvent, source: String) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _selected_skill and _skill_manager:
			_equip(source, _selected_skill)
			_selected_skill = null
			_refresh_all()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _skill_manager:
			_unequip(source)
			_refresh_all()


func _equip(source: String, skill: SkillData) -> void:
	match source:
		"left":  _skill_manager.equip_hand("left", skill)
		"right": _skill_manager.equip_hand("right", skill)
		_:       _skill_manager.equip_slot(source.trim_prefix("slot_").to_int(), skill)


func _unequip(source: String) -> void:
	match source:
		"left":  _skill_manager.unequip_hand("left")
		"right": _skill_manager.unequip_hand("right")
		_:       _skill_manager.unequip_slot(source.trim_prefix("slot_").to_int())


func _on_hand_changed(_hand: String) -> void:
	if visible: _refresh_all()


func _on_slot_changed(_idx: int) -> void:
	if visible: _refresh_all()


## ── 刷新 ──

func _refresh_all() -> void:
	_refresh_grid()
	_refresh_equip_slots()


func _refresh_grid() -> void:
	for child in _skill_grid.get_children():
		child.queue_free()
	if not _skill_pool:
		return
	for skill in _skill_pool.skills:
		if not skill: continue
		var card := _make_skill_card(skill)
		_skill_grid.add_child(card)


func _make_skill_card(skill: SkillData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(90, 110)
	card.add_theme_stylebox_override("panel", _make_card_bg(skill == _selected_skill))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	if skill.icon: icon.texture = skill.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var nm := Label.new()
	nm.text = skill.display_name
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color", Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(nm)

	var tp := Label.new()
	tp.text = _type_name(skill.skill_type)
	tp.add_theme_font_size_override("font_size", 9)
	tp.add_theme_color_override("font_color", _type_color(skill.skill_type))
	tp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tp)

	card.gui_input.connect(_on_card_clicked.bind(skill))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	return card


func _on_card_clicked(event: InputEvent, skill: SkillData) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selected_skill = skill
		_refresh_all()


func _refresh_equip_slots() -> void:
	for i in range(_equip_sources.size()):
		var src := _equip_sources[i]
		var panel := _equip_slots[i]
		var skill: SkillData = null
		match src:
			"left":
				if _skill_manager.left_hand:
					skill = _skill_manager.left_hand.data
			"right":
				if _skill_manager.right_hand:
					skill = _skill_manager.right_hand.data
			_:
				var inst := _skill_manager.get_slot(src.trim_prefix("slot_").to_int())
				if inst:
					skill = inst.data

		var hbox := panel.get_child(0) as HBoxContainer
		var tex := hbox.get_node("Icon") as TextureRect
		var vbox := hbox.get_child(1) as VBoxContainer
		var name_lbl := vbox.get_node("Name") as Label

		if skill:
			if skill.icon: tex.texture = skill.icon; tex.modulate = Color(1,1,1,1)
			else: tex.texture = null; tex.modulate = Color(1,1,1,0.3)
			name_lbl.text = skill.display_name
		else:
			tex.texture = null; tex.modulate = Color(1,1,1,0.1)
			name_lbl.text = "空"

		if _selected_skill and skill == _selected_skill:
			panel.add_theme_stylebox_override("panel", _make_slot_bg(Color(0.3, 0.5, 0.3)))
		else:
			panel.add_theme_stylebox_override("panel", _make_slot_bg())


## ── 样式 ──

func _make_panel_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.4, 0.4, 0.5, 1)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	return sb


func _make_card_bg(selected: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.3, 0.2, 1) if selected else Color(0.15, 0.15, 0.2, 0.9)
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.5, 0.8, 0.5, 1) if selected else Color(0.25, 0.25, 0.35, 1)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb


func _make_slot_bg(color_override := Color(0.12, 0.12, 0.18, 0.9)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color_override
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.3, 0.4, 1)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb


func _type_name(t: int) -> String:
	match t:
		SkillData.SkillType.PROJECTILE: return "🎯"
		SkillData.SkillType.BUFF:       return "🛡️"
		SkillData.SkillType.AOE:        return "💥"
		SkillData.SkillType.DASH:       return "💨"
	return "?"


func _type_color(t: int) -> Color:
	match t:
		SkillData.SkillType.PROJECTILE: return Color(1.0, 0.5, 0.3)
		SkillData.SkillType.BUFF:       return Color(0.3, 0.7, 1.0)
		SkillData.SkillType.AOE:        return Color(1.0, 0.3, 0.3)
		SkillData.SkillType.DASH:       return Color(0.3, 1.0, 0.5)
	return Color.GRAY
