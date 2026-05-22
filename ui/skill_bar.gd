class_name SkillBar
extends HBoxContainer
## 技能条 — 左手 [L] · 右手 [R] · 槽1 [1] · 槽2 [2] · 槽3 [3] · 槽4 [4]

const SLOT_SIZE := Vector2(48, 48)
const HAND_SIZE := Vector2(56, 48)

var _skill_manager: SkillManager = null
var _panels: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _masks: Array[ColorRect] = []
var _bind_labels: Array[Label] = []
var _cd_labels: Array[Label] = []
var _sources: Array[String] = []  ## "left", "right", "slot_0", ...


func setup(sm: SkillManager) -> void:
	_skill_manager = sm
	_skill_manager.hand_changed.connect(_on_hand_changed)
	_skill_manager.slot_changed.connect(_on_slot_changed)
	_skill_manager.cooldown_changed.connect(_on_cooldown)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_panels.clear(); _icons.clear(); _masks.clear(); _bind_labels.clear(); _cd_labels.clear(); _sources.clear()

	# 左手
	_add_item("left", "L", HAND_SIZE)
	# 右手
	_add_item("right", "R", HAND_SIZE)
	# 快捷键 1-4
	for i in range(4):
		_add_item("slot_%d" % i, str(i + 1), SLOT_SIZE)

	_refresh_all()


func _add_item(source: String, label: String, size: Vector2) -> void:
	_sources.append(source)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.add_theme_stylebox_override("panel", _make_bg())
	add_child(panel)
	_panels.append(panel)

	var inner := Control.new()
	inner.custom_minimum_size = size
	inner.clip_contents = true
	panel.add_child(inner)

	var icon := TextureRect.new()
	icon.size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 0.3)
	inner.add_child(icon)
	_icons.append(icon)

	var mask := ColorRect.new()
	mask.size = Vector2(size.x, 0)
	mask.color = Color(0, 0, 0, 0.6)
	mask.visible = false
	inner.add_child(mask)
	_masks.append(mask)

	var cd_label := Label.new()
	cd_label.size = size
	cd_label.add_theme_font_size_override("font_size", 14)
	cd_label.add_theme_color_override("font_color", Color.WHITE)
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.visible = false
	inner.add_child(cd_label)
	_cd_labels.append(cd_label)

	var bind_label := Label.new()
	bind_label.add_theme_font_size_override("font_size", 9)
	bind_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	bind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bind_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	bind_label.size = Vector2(size.x - 2, size.y - 2)
	bind_label.position = Vector2.ZERO
	bind_label.text = label
	inner.add_child(bind_label)
	_bind_labels.append(bind_label)


func _refresh_all() -> void:
	for i in range(_sources.size()):
		_refresh_idx(i)


func _refresh_idx(idx: int) -> void:
	var src := _sources[idx]
	var skill: SkillData = null
	match src:
		"left":  skill = _skill_manager.left_hand.data if _skill_manager.left_hand else null
		"right": skill = _skill_manager.right_hand.data if _skill_manager.right_hand else null
		_:
			var inst := _skill_manager.get_slot(src.trim_prefix("slot_").to_int())
			skill = inst.data if inst else null

	var icon := _icons[idx]
	if skill and skill.icon:
		icon.texture = skill.icon
		icon.modulate = Color(1, 1, 1, 1)
	elif skill:
		icon.texture = null
		icon.modulate = Color(1, 1, 1, 0.5)
	else:
		icon.texture = null
		icon.modulate = Color(1, 1, 1, 0.12)
	
	_bind_labels[idx].visible = (skill == null)
	_update_cooldown(idx)


func _update_cooldown(idx: int) -> void:
	var remaining := _skill_manager.get_cooldown(_sources[idx])
	var total := _skill_manager.get_cooldown_total(_sources[idx])
	var size := HAND_SIZE if idx < 2 else SLOT_SIZE
	var mask := _masks[idx]
	var cd_label := _cd_labels[idx]

	if remaining > 0 and total > 0:
		mask.size = Vector2(size.x, size.y * remaining / total)
		mask.visible = true
		cd_label.text = "%.1f" % remaining
		cd_label.visible = true
	else:
		mask.visible = false
		cd_label.visible = false


func _on_hand_changed(_hand: String) -> void:
	for i in range(_sources.size()):
		if _sources[i] == "left" or _sources[i] == "right":
			_refresh_idx(i)


func _on_slot_changed(_idx: int) -> void:
	for i in range(_sources.size()):
		if _sources[i].begins_with("slot_"):
			_refresh_idx(i)


func _on_cooldown(source: String, _remaining: float, _total: float) -> void:
	for i in range(_sources.size()):
		if _sources[i] == source:
			_update_cooldown(i)
			return


func _make_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.3, 0.3, 0.4, 1)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	return sb
