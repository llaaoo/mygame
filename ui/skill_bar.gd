class_name SkillBar
extends HBoxContainer
## 技能条 — 双手施法与六个快捷施法槽。

const SLOT_SIZE := Vector2(46, 46)
const HAND_SIZE := Vector2(50, 46)

var _skill_manager: SkillManager = null
var _panels: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _masks: Array[ColorRect] = []
var _bind_labels: Array[Label] = []
var _cd_labels: Array[Label] = []
var _sources: Array[String] = []  ## "left", "right", "slot_0", ...
var _combination_hint: Label


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
	# 快捷键 1-6
	for i in range(6):
		_add_item("slot_%d" % i, str(i + 1), SLOT_SIZE)

	_refresh_all()
	_combination_hint = Label.new()
	_combination_hint.set_as_top_level(true)
	_combination_hint.size = Vector2(440, 68)
	_combination_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combination_hint.add_theme_font_size_override("font_size", 12)
	_combination_hint.add_theme_color_override("font_color", Color(1, 0.75, 0.4))
	_combination_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combination_hint)


func _process(_delta: float) -> void:
	if not _skill_manager or not _skill_manager.combinations or not is_instance_valid(_combination_hint):
		return
	var controller := _skill_manager.combinations
	var ignite := _skill_manager.pool.get_skill("ignite") if _skill_manager.pool else null
	if not ignite:
		_combination_hint.hide()
		return
	var plan := controller.preview(ignite, _skill_manager.get_parent(), Input.is_key_pressed(KEY_SHIFT))
	var action_name := "火花"
	if not controller.pending.is_empty():
		plan = controller.pending
		action_name = plan.action.display_name
	var text := "%s → %s · %d MP" % [action_name, plan.effect_label, plan.cost]
	if not plan.material_costs.is_empty():
		text += " · " + controller.supplies.describe_cost(plan.material_costs)
	var boon_hint := controller.boon_hint(plan)
	if not boon_hint.is_empty():
		text += "\n" + boon_hint
	if not controller.pending.is_empty():
		text += "\n准备：%s · %.1fs" % [controller.pending.effect_label, maxf(0, controller.pending.remaining)]
	elif not controller.last_message.is_empty():
		text += "\n" + controller.last_message
	elif not plan.ready:
		text += "\n" + plan.reason
	_combination_hint.text = text
	_combination_hint.global_position = global_position + Vector2(0, -68)
	for i in range(_sources.size()):
		_update_cooldown(i)
		var instance := _skill_manager.get_instance(_sources[i])
		if instance and controller.handles(instance.data):
			var preview := controller.preview(instance.data, _skill_manager.get_parent(), Input.is_key_pressed(KEY_SHIFT))
			_panels[i].tooltip_text = "%s → %s · %d MP\n%s\n%s\n%s" % [instance.data.display_name, preview.effect_label, preview.cost, controller.supplies.describe_cost(preview.material_costs) if not preview.material_costs.is_empty() else "无材料消耗", controller.boon_hint(preview), preview.reason if not preview.ready else preview.skill.description]


func _add_item(source: String, label: String, size: Vector2) -> void:
	_sources.append(source)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.add_theme_stylebox_override("panel", GameUIStyle.slot_style(source in ["left", "right"]))
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
	mask.color = Color(0.01, 0.015, 0.02, 0.76)
	mask.visible = false
	inner.add_child(mask)
	_masks.append(mask)

	var cd_label := Label.new()
	cd_label.size = size
	cd_label.add_theme_font_size_override("font_size", 13)
	cd_label.add_theme_color_override("font_color", Color.WHITE)
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.visible = false
	inner.add_child(cd_label)
	_cd_labels.append(cd_label)

	var bind_label := Label.new()
	bind_label.add_theme_font_size_override("font_size", 9)
	bind_label.add_theme_color_override("font_color", GameUIStyle.TEXT_MUTED)
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
	if skill:
		icon.texture = SkillIconCatalog.get_icon(skill)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = Color(1, 1, 1, 1)
	else:
		icon.texture = null
		icon.modulate = Color(1, 1, 1, 0.12)
	
	_bind_labels[idx].visible = true
	_panels[idx].tooltip_text = "%s\n%s" % [skill.display_name, skill.description] if skill else "空槽"
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
