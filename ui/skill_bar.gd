class_name SkillBar
extends HBoxContainer
## 技能条 — 双手施法与六个快捷施法槽。

class TooltipSlot extends PanelContainer:
	func _make_custom_tooltip(for_text: String) -> Object:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.99, 5, GameUIStyle.BORDER_STRONG))
		var label := Label.new()
		label.custom_minimum_size.x = 350
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = for_text
		GameUIStyle.apply_label(label, 12, GameUIStyle.TEXT_MAIN)
		panel.add_child(label)
		return panel

const SLOT_SIZE := Vector2(46, 46)
const HAND_SIZE := Vector2(50, 46)

var _skill_manager: SkillManager = null
var _panels: Array[PanelContainer] = []
var _icons: Array[TextureRect] = []
var _masks: Array[ColorRect] = []
var _bind_labels: Array[Label] = []
var _cd_labels: Array[Label] = []
var _sources: Array[String] = []  ## "left", "right", "slot_0", ...
var _preview_elapsed := 0.1
var _preview_position := Vector2.ZERO
var _preview_empower := false
var _combination_hint: Label
var _hint_panel: PanelContainer
var _preparation_bar: ProgressBar
var _cost_labels: Array[Label] = []
var _affinity_strips: Array[ColorRect] = []
var _icon_keys: Array = []


func setup(sm: SkillManager) -> void:
	_skill_manager = sm
	_skill_manager.hand_changed.connect(_on_hand_changed)
	_skill_manager.slot_changed.connect(_on_slot_changed)
	_skill_manager.cooldown_changed.connect(_on_cooldown)
	_skill_manager.hand_changed.connect(_invalidate_previews)
	_skill_manager.slot_changed.connect(_invalidate_previews)
	_skill_manager.skill_upgraded.connect(_invalidate_previews)
	_skill_manager.cast_committed.connect(_invalidate_previews)
	_skill_manager.combinations.supplies.changed.connect(_invalidate_previews)
	var buffs := sm.get_parent().get_node_or_null("BuffManager") as BuffManager
	if buffs: buffs.buffs_changed.connect(_invalidate_previews)
	var equipment := sm.get_parent().get_node_or_null("EquipmentManager") as EquipmentManager
	if equipment: equipment.loadout_changed.connect(_invalidate_previews)
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_cost_labels.clear(); _affinity_strips.clear(); _icon_keys.clear()
	_panels.clear(); _icons.clear(); _masks.clear(); _bind_labels.clear(); _cd_labels.clear(); _sources.clear()

	# 左手
	_add_item("left", "L", HAND_SIZE)
	# 右手
	_add_item("right", "R", HAND_SIZE)
	# 快捷键 1-6
	for i in range(6):
		_add_item("slot_%d" % i, str(i + 1), SLOT_SIZE)

	_refresh_all()
	_hint_panel = PanelContainer.new()
	_hint_panel.set_as_top_level(true)
	_hint_panel.custom_minimum_size.x = 466
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.94, 5))
	add_child(_hint_panel)
	var details := VBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(details)
	_combination_hint = Label.new()
	_combination_hint.custom_minimum_size.x = 440
	_combination_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combination_hint.add_theme_font_size_override("font_size", 12)
	_combination_hint.add_theme_color_override("font_color", GameUIStyle.TEXT_MAIN)
	_combination_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(_combination_hint)
	_preparation_bar = ProgressBar.new()
	_preparation_bar.show_percentage = false
	_preparation_bar.max_value = 1
	GameUIStyle.apply_progress(_preparation_bar, GameUIStyle.GOLD, 5)
	_preparation_bar.hide()
	details.add_child(_preparation_bar)


func _process(_delta: float) -> void:
	if not _skill_manager or not _skill_manager.combinations or not is_instance_valid(_combination_hint):
		return
	var empower := Input.is_key_pressed(KEY_SHIFT)
	var actor_position: Vector2 = _skill_manager.get_parent().global_position
	if empower != _preview_empower or not actor_position.is_equal_approx(_preview_position): _invalidate_previews()
	_preview_empower = empower
	_preview_position = actor_position
	_preview_elapsed += _delta
	if _preview_elapsed < 0.1: return
	_preview_elapsed = 0.0
	var controller := _skill_manager.combinations
	var actor := _skill_manager.get_parent() as Player
	var source := actor.casting.aimed_source() if actor else ""
	var hint_instance := _skill_manager.get_instance(source if not source.is_empty() else "right")
	if not hint_instance:
		for candidate in _sources:
			hint_instance = _skill_manager.get_instance(candidate)
			if hint_instance: break
	var action := hint_instance.data if hint_instance else null
	if not action:
		_combination_hint.hide()
		return
	_combination_hint.show()
	var previews: Dictionary = {}
	var hint_key := hash([hint_instance.base_data, hint_instance.upgrade_ranks])
	previews[hint_key] = controller.preview(action, _skill_manager.get_parent(), empower)
	var plan: CastPlan = previews[hint_key]
	var action_name: String = action.display_name
	if not controller.pending.is_empty():
		plan = controller.pending
		action_name = plan.action.display_name
	var text := ("Shift · " if empower else "") + "%s → %s · %d MP" % [action_name, plan.effect_label, plan.cost]
	text += " · " + controller.effect_scope(plan.skill)
	if not plan.material_costs.is_empty():
		text += " · " + controller.supplies.describe_cost(plan.material_costs)
	var boon_hint := controller.boon_hint(plan)
	if not boon_hint.is_empty():
		text += "\n" + boon_hint
	if not controller.pending.is_empty():
		text += "\n准备：%s · %.1fs" % [controller.pending.effect_label, maxf(0, controller.pending.remaining)]
	elif not plan.ready:
		text += "\n" + plan.reason
	elif source.is_empty() and not controller.last_message.is_empty():
		text += "\n" + controller.last_message
	_combination_hint.text = text
	_preparation_bar.visible = not controller.pending.is_empty()
	if _preparation_bar.visible:
		_preparation_bar.value = 1 - controller.pending.remaining / maxf(.001, controller.pending.preparation)
	_hint_panel.size = Vector2(466, 0)
	_hint_panel.global_position = global_position + Vector2(0, -_hint_panel.size.y - 12)
	for i in range(_sources.size()):
		var instance := _skill_manager.get_instance(_sources[i])
		var preview: CastPlan
		if instance and controller.handles(instance.data):
			var key := hash([instance.base_data, instance.upgrade_ranks])
			if not previews.has(key):
				previews[key] = controller.preview(instance.data, _skill_manager.get_parent(), empower)
			preview = previews[key]
			var comparison_key := str(key) + ":comparison"
			if not previews.has(comparison_key):
				var alternate := controller.preview(instance.data, _skill_manager.get_parent(), not empower)
				previews[comparison_key] = instance.data.display_name + "\n\n普通 · " + _brief_plan(alternate if empower else preview) + "\n\nShift · " + _brief_plan(preview if empower else alternate) + "\n\n数字为本次MP费用 · M查看完整材料与条件"
			_panels[i].tooltip_text = previews[comparison_key]
		if preview:
			var icon_key: Variant = preview.skill.icon if preview.skill.icon else preview.skill.icon_atlas_index
			if _icon_keys[i] != icon_key:
				_icons[i].texture = SkillIconCatalog.get_icon(preview.skill)
				_icon_keys[i] = icon_key
			_cost_labels[i].text = "%d" % preview.cost
			_cost_labels[i].modulate = GameUIStyle.TEXT_MAIN if preview.ready else GameUIStyle.GOLD
			var accent := ElementVisuals.color_for(preview.skill.tags)
			_affinity_strips[i].color = Color(accent, .85)
			(_panels[i].get_theme_stylebox("panel") as StyleBoxFlat).border_color = accent if not preview.rule_id.is_empty() else GameUIStyle.PANEL_BORDER
		_update_cooldown(i, preview)

func _invalidate_previews(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_preview_elapsed = 0.1


func _add_item(source: String, label: String, size: Vector2) -> void:
	_sources.append(source)

	var panel := TooltipSlot.new()
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
	_icon_keys.append(null)
	var strip := ColorRect.new()
	strip.size = Vector2(size.x, 2)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(strip)
	_affinity_strips.append(strip)
	var cost := Label.new()
	cost.position = Vector2(2, 3)
	GameUIStyle.apply_label(cost, 10, GameUIStyle.TEXT_MAIN)
	cost.add_theme_color_override("font_shadow_color", Color.BLACK)
	cost.add_theme_constant_override("shadow_offset_x", 1)
	cost.add_theme_constant_override("shadow_offset_y", 1)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(cost)
	_cost_labels.append(cost)

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
	_icon_keys[idx] = (skill.icon if skill.icon else skill.icon_atlas_index) if skill else null
	if skill:
		icon.texture = SkillIconCatalog.get_icon(skill)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = Color(1, 1, 1, 1)
	else:
		icon.texture = null
		icon.modulate = Color(1, 1, 1, 0.12)

	_affinity_strips[idx].color = Color(ElementVisuals.color_for(skill.tags), .8) if skill else Color.TRANSPARENT
	_cost_labels[idx].text = str(skill.mp_cost) if skill else ""
	_cost_labels[idx].tooltip_text = "本次法力费用"
	_bind_labels[idx].visible = true
	_panels[idx].tooltip_text = "%s\n%s" % [skill.display_name, skill.description] if skill else "空槽"
	_update_cooldown(idx)


func _update_cooldown(idx: int, plan: CastPlan = null) -> void:
	var state := _skill_manager.get_cooldown_state(_sources[idx], plan)
	var remaining: float = state.remaining
	var total: float = state.duration
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

func _brief_plan(plan: CastPlan) -> String:
	var text := plan.effect_label + " · %d MP" % plan.cost
	if not plan.material_costs.is_empty(): text += "\n" + _skill_manager.combinations.supplies.describe_cost(plan.material_costs)
	var boon := _skill_manager.combinations.boon_hint(plan)
	if not boon.is_empty(): text += "\n" + boon
	if not plan.ready: text += "\n" + plan.reason
	return text
