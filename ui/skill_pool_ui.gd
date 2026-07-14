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
var _detail_box: VBoxContainer = null


func _ready() -> void:
	layer = 160  # 高于 RunOverlay(140)，避免房间目标遮挡面板
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
	sm.skill_upgraded.connect(_on_skill_upgraded)


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
	_panel.anchor_top = 0.04; _panel.anchor_bottom = 0.96
	_panel.clip_contents = true
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
	title.text = "技能编组"
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
	right_vbox.custom_minimum_size = Vector2(260, 0)
	right_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(right_vbox)

	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(260, 155)
	detail_panel.add_theme_stylebox_override("panel", _make_slot_bg())
	right_vbox.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 10)
	detail_margin.add_theme_constant_override("margin_right", 10)
	detail_margin.add_theme_constant_override("margin_top", 8)
	detail_margin.add_theme_constant_override("margin_bottom", 8)
	detail_panel.add_child(detail_margin)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	detail_margin.add_child(_detail_box)

	right_vbox.add_child(_make_section_label("双手法术"))
	_add_equip_slot(right_vbox, "left", "左手")
	_add_equip_slot(right_vbox, "right", "右手")

	right_vbox.add_child(_make_section_label("快捷法术"))
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
	panel.custom_minimum_size = Vector2(200, 34)
	panel.add_theme_stylebox_override("panel", _make_slot_bg())
	panel.set_meta("display_label", label)
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
	if not _is_skill_unlocked(skill):
		_hint_label.text = "%s 需要 %s Lv.%d" % [skill.display_name, _school_name(skill.school), _unlock_level(skill)]
		return
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


func _on_skill_upgraded(_source: String, _skill: SkillData, _upgrade_id: String, _rank: int) -> void:
	if visible: _refresh_all()


## ── 刷新 ──

func _refresh_all() -> void:
	_refresh_grid()
	_refresh_equip_slots()
	_refresh_detail()


func _refresh_detail() -> void:
	if not _detail_box:
		return
	for child in _detail_box.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = _selected_skill.display_name if _selected_skill else "法术详情"
	GameUIStyle.apply_label(heading, 16, GameUIStyle.GOLD)
	_detail_box.add_child(heading)
	if not _selected_skill:
		var empty := Label.new()
		empty.text = "选择一个法术查看完整数值。"
		GameUIStyle.apply_label(empty, 10, GameUIStyle.TEXT_MUTED)
		_detail_box.add_child(empty)
		return
	if not _is_skill_unlocked(_selected_skill):
		var locked := Label.new()
		locked.text = "未解锁 · %s Lv.%d" % [_school_name(_selected_skill.school), _unlock_level(_selected_skill)]
		GameUIStyle.apply_label(locked, 10, Color(0.94, 0.5, 0.32, 1.0))
		_detail_box.add_child(locked)
	var desc := Label.new()
	desc.text = _selected_skill.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(desc, 10, GameUIStyle.TEXT_MAIN)
	_detail_box.add_child(desc)
	var stats := Label.new()
	stats.text = _format_skill_stats(_selected_skill)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(stats, 10, GameUIStyle.TEXT_MUTED)
	_detail_box.add_child(stats)
	if not _selected_skill.mechanics.is_empty():
		var mechanics := Label.new()
		mechanics.text = _selected_skill.mechanics
		mechanics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		GameUIStyle.apply_label(mechanics, 10, Color(0.64, 0.82, 0.92, 1.0))
		_detail_box.add_child(mechanics)
	var build := Label.new()
	var branches: Array[String] = []
	for upgrade in _selected_skill.upgrades:
		if upgrade:
			branches.append(str(upgrade.get("branch")))
	var synergy_names: Array[String] = []
	for synergy in _selected_skill.synergies:
		if synergy:
			synergy_names.append(str(synergy.get("display_name")))
	build.text = "强化: %s\n联动: %s" % [", ".join(branches), ", ".join(synergy_names) if not synergy_names.is_empty() else "无"]
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUIStyle.apply_label(build, 9, GameUIStyle.TEXT_MUTED)
	_detail_box.add_child(build)


func _format_skill_stats(skill: SkillData) -> String:
	var lines: Array[String] = [
		"%s · T%d · %s" % [_type_name(skill.skill_type), skill.tier, skill.role],
		"伤害 %d  |  法力 %d  |  冷却 %.1fs" % [skill.damage, skill.mp_cost, skill.cooldown],
	]
	match skill.skill_type:
		SkillData.SkillType.PROJECTILE:
			lines.append("弹速 %.0f  |  数量 %d  |  穿透 %d" % [skill.projectile_speed, skill.projectile_count, skill.projectile_pierce])
		SkillData.SkillType.AOE:
			var radius := skill.aoe_visual.radius if skill.aoe_visual else skill.aoe_radius
			var lifetime := skill.aoe_visual.lifetime if skill.aoe_visual else skill.aoe_lifetime
			lines.append("半径 %.0f  |  持续 %.1fs  |  命中 %d" % [radius, lifetime, skill.aoe_max_hits_per_target])
		SkillData.SkillType.BUFF:
			lines.append("持续 %.1fs" % skill.buff_duration)
		SkillData.SkillType.DASH:
			lines.append("距离 %.0f  |  速度 %.0f" % [skill.dash_distance, skill.dash_speed])
		SkillData.SkillType.SUMMON:
			if skill.summon_data:
				lines.append("召唤生命 %d  |  伤害 %d  |  存在 %.0fs" % [skill.summon_data.max_hp, skill.summon_data.damage, skill.summon_data.lifetime])
	return "\n".join(lines)


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
	var unlocked := _is_skill_unlocked(skill)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(90, 110)
	card.add_theme_stylebox_override("panel", _make_card_bg(skill == _selected_skill))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.texture = SkillIconCatalog.get_icon(skill)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if unlocked else Color(0.34, 0.36, 0.4, 0.78)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	var nm := Label.new()
	nm.text = skill.display_name
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color", Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(nm)

	var tp := Label.new()
	tp.text = "%s · %s" % [_type_name(skill.skill_type), "%d 路" % skill.upgrades.size() if unlocked else "Lv.%d" % _unlock_level(skill)]
	tp.add_theme_font_size_override("font_size", 9)
	tp.add_theme_color_override("font_color", _type_color(skill.skill_type))
	tp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tp)

	card.gui_input.connect(_on_card_clicked.bind(skill))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "%s\n%s\n%s" % [skill.description, skill.mechanics, "已解锁" if unlocked else "%s Lv.%d 解锁" % [_school_name(skill.school), _unlock_level(skill)]]
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
		var inst: SkillInstance = null
		match src:
			"left":
				if _skill_manager.left_hand:
					inst = _skill_manager.left_hand
			"right":
				if _skill_manager.right_hand:
					inst = _skill_manager.right_hand
			_:
				inst = _skill_manager.get_slot(src.trim_prefix("slot_").to_int())
		if inst:
			skill = inst.data

		var hbox := panel.get_child(0) as HBoxContainer
		var tex := hbox.get_node("Icon") as TextureRect
		var vbox := hbox.get_child(1) as VBoxContainer
		var name_lbl := vbox.get_node("Name") as Label
		var sub_lbl := vbox.get_node("Sub") as Label
		var display_label := str(panel.get_meta("display_label", ""))

		if skill:
			var skill_icon := SkillIconCatalog.get_icon(skill)
			if skill_icon: tex.texture = skill_icon; tex.modulate = Color(1,1,1,1)
			else: tex.texture = null; tex.modulate = Color(1,1,1,0.3)
			name_lbl.text = skill.display_name
			var total_ranks := 0
			for rank in inst.upgrade_ranks.values():
				total_ranks += int(rank)
			sub_lbl.text = "%s | 强化 %d" % [display_label, total_ranks]
		else:
			tex.texture = null; tex.modulate = Color(1,1,1,0.1)
			name_lbl.text = "空"
			sub_lbl.text = display_label

		if _selected_skill and skill and skill.get_id() == _selected_skill.get_id():
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
		SkillData.SkillType.PROJECTILE: return "投射"
		SkillData.SkillType.BUFF:       return "增益"
		SkillData.SkillType.AOE:        return "范围"
		SkillData.SkillType.DASH:       return "位移"
		SkillData.SkillType.SUMMON:     return "召唤"
	return "法术"


func _is_skill_unlocked(skill: SkillData) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	return not player or not player.mastery_manager or player.mastery_manager.is_spell_unlocked(skill)


func _unlock_level(skill: SkillData) -> int:
	var player := get_tree().get_first_node_in_group("player") as Player
	return player.mastery_manager.get_spell_unlock_level(skill) if player and player.mastery_manager else 1


func _school_name(school: int) -> String:
	match school:
		SkillMastery.School.DESTRUCTION: return "毁灭"
		SkillMastery.School.CONJURATION: return "召唤"
		SkillMastery.School.RESTORATION: return "恢复"
		SkillMastery.School.ALTERATION: return "变化"
		SkillMastery.School.ILLUSION: return "幻术"
	return "精通"


func _type_color(t: int) -> Color:
	match t:
		SkillData.SkillType.PROJECTILE: return Color(1.0, 0.5, 0.3)
		SkillData.SkillType.BUFF:       return Color(0.3, 0.7, 1.0)
		SkillData.SkillType.AOE:        return Color(1.0, 0.3, 0.3)
		SkillData.SkillType.DASH:       return Color(0.3, 1.0, 0.5)
		SkillData.SkillType.SUMMON:     return Color(0.7, 0.4, 1.0)
	return Color.GRAY
