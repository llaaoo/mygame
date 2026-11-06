class_name ExpeditionUI
extends CanvasLayer

signal travel_requested(destination: String)
signal retreat_requested
signal replay_requested
signal practice_requested
signal materials_requested
signal elements_requested
signal trials_requested
signal equipment_requested
signal survival_requested

var heading: Label
var objective: Label
var message: Label
var modal: CanvasLayer
var _message_time := 0.0
var progress: ExplorationProgress
var modal_locked := false
var journal_provider: Callable
var map_provider: Callable
var pause_provider: Callable
var practice_available: Callable
var _heading_panel: PanelContainer
var _notice: PanelContainer
var _modal_panel: PanelContainer
var _terrain_label: Label
var _terrain_time := 0.0
var _survival_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = GameUIStyle.LAYER_RUN
	var panel := PanelContainer.new()
	_heading_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = 8
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.94, 5, GameUIStyle.BORDER_STRONG))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	heading = _label("余烬监狱", 20)
	objective = _label("", 12)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	box.add_child(objective)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -214
	footer.offset_right = -18
	footer.offset_top = -68
	footer.offset_bottom = -18
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.85, 4))
	add_child(footer)
	var controls := _label("J 日志 M 材料 O 装备\nN 补给 K 编组 Esc 暂停", 11)
	GameUIStyle.apply_label(controls, 11, GameUIStyle.TEXT_MUTED)
	footer.add_child(controls)
	var needs_panel := PanelContainer.new()
	needs_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	needs_panel.offset_left = 20
	needs_panel.offset_right = 290
	needs_panel.offset_top = 136
	needs_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	needs_panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.85, 4))
	add_child(needs_panel)
	_survival_label = _label("饱食100 · 饮水100 · 疲劳0", 12)
	_survival_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs_panel.add_child(_survival_label)
	var terrain := PanelContainer.new()
	terrain.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	terrain.offset_left = 18
	terrain.offset_right = 216
	terrain.offset_top = -68
	terrain.offset_bottom = -18
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.85, 4))
	add_child(terrain)
	_terrain_label = _label("脚下 · 干地", 12)
	terrain.add_child(_terrain_label)
	_notice = PanelContainer.new()
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice.offset_left = -250
	_notice.offset_right = 250
	_notice.offset_top = 112
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.94, 5, GameUIStyle.BORDER_STRONG))
	add_child(_notice)
	message = _label("", 14)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_child(message)
	_notice.hide()
	get_viewport().size_changed.connect(_layout_modal)
	_layout_modal()

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(label, size, GameUIStyle.TEXT_MAIN)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _process(delta: float) -> void:
	_terrain_time += delta
	if _terrain_time >= .2:
		_terrain_time = 0
		_update_terrain()
	if not get_tree().paused:
		_message_time -= delta
		if _message_time <= 0:
			message.text = ""
			_notice.hide()

func notify(text: String) -> void:
	_notice.show()
	message.text = text
	_message_time = 5.0

func set_survival_status(text: String) -> void:
	if _survival_label: _survival_label.text = text

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			if not modal_locked:
				close_modal()
		else:
			show_pause()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_J:
		if modal_locked:
			return
		if is_instance_valid(modal):
			close_modal()
		else:
			show_journal()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_G and map_provider.is_valid():
		if modal_locked: return
		if is_instance_valid(modal): close_modal()
		else: map_provider.call()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_M:
		if modal_locked:
			return
		if is_instance_valid(modal):
			close_modal()
		else:
			materials_requested.emit()
		get_viewport().set_input_as_handled()

	elif event.keycode == KEY_N:
		if modal_locked: return
		if is_instance_valid(modal): close_modal()
		else: survival_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_O:
		if modal_locked:
			return
		if is_instance_valid(modal):
			close_modal()
		else:
			equipment_requested.emit()
		get_viewport().set_input_as_handled()

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		GameUIStyle.end_modal(modal)
		modal.queue_free()
	modal = null
	_modal_panel = null
	modal_locked = false

func show_panel(title: String, text: String, buttons: Array[Dictionary], locked: bool = false) -> void:
	close_modal()
	modal_locked = locked
	modal = CanvasLayer.new()
	modal.layer = GameUIStyle.LAYER_MODAL + 1
	modal.process_mode = Node.PROCESS_MODE_ALWAYS
	modal.add_to_group("modal_ui")
	add_child(modal)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = GameUIStyle.modal_backdrop()
	modal.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_modal_panel = panel
	panel.name = "ContentPanel"
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.99, 6, GameUIStyle.BORDER_STRONG))
	backdrop.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var title_label := _label(title, 23)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.tooltip_text = title
	title_row.add_child(title_label)
	if not locked:
		var close := Button.new()
		close.text = "关闭"
		close.tooltip_text = "Esc · 关闭窗口"
		GameUIStyle.apply_button(close, GameUIStyle.GOLD)
		close.pressed.connect(close_modal)
		title_row.add_child(close)
	box.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.custom_minimum_size = Vector2(0, 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var body := RichTextLabel.new()
	body.fit_content = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.scroll_active = false
	body.selection_enabled = true
	body.text = text
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_color_override("default_color", GameUIStyle.TEXT_MAIN)
	body.add_theme_constant_override("line_separation", 5)
	scroll.add_child(body)
	scroll.resized.connect(func(): body.custom_minimum_size.x = maxf(1, scroll.size.x - 20))
	var button_host: Container = box
	if buttons.size() > 3:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		if buttons.size() > 6:
			var button_scroll := ScrollContainer.new()
			button_scroll.custom_minimum_size.y = 176
			box.add_child(button_scroll)
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button_scroll.add_child(grid)
		else:
			box.add_child(grid)
		button_host = grid
	var first_button: Button
	for entry in buttons:
		var button := Button.new()
		button.text = entry.title
		button.clip_text = true
		button.tooltip_text = entry.get("tooltip", entry.title)
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = bool(entry.get("disabled", false))
		GameUIStyle.apply_button(button)
		button.pressed.connect(entry.callback)
		button_host.add_child(button)
		if not button.disabled and first_button == null: first_button = button
	_layout_modal()
	if first_button: first_button.call_deferred("grab_focus")
	GameUIStyle.begin_modal(modal)

func _layout_modal() -> void:
	var viewport := get_viewport().get_visible_rect().size
	if is_instance_valid(_heading_panel):
		var width := minf(420, viewport.x - 580)
		_heading_panel.offset_left = -width * .5
		_heading_panel.offset_right = width * .5
	if not is_instance_valid(_modal_panel): return
	var extent := Vector2(minf(760, viewport.x - 48), minf(548, viewport.y - 48))
	_modal_panel.offset_left = -extent.x * .5
	_modal_panel.offset_right = extent.x * .5
	_modal_panel.offset_top = -extent.y * .5
	_modal_panel.offset_bottom = extent.y * .5

func _update_terrain() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player or not GameRuntime.instance: return
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	var state: String = surfaces.surface_at(player.global_position).state
	var title := SurfaceManager.surface_title(state)
	var detail: String = {"dry": "Shift 施法 · 恩赐兑现", "wet": "清洗 / 凝霜 / 导电", "frozen": "凝霜控制 · 冲击可破冰", "burning": "燃烧危险 · 水可灭火", "electrified": "感电危险 · 注意站位", "poisoned": "中毒危险 · 清水可清洗", "steam": "蒸汽掩护 · 投射物减伤", "oiled": "可燃介质 · 小心引火"}.get(state, "")
	_terrain_label.text = "脚下 · " + title + "\n" + detail
	_terrain_label.add_theme_color_override("font_color", GameUIStyle.TEXT_MUTED if state == "dry" else Color(SurfaceCatalog.color_for(state), 1))

func show_pause() -> void:
	if pause_provider.is_valid():
		pause_provider.call()
		return
	show_panel("远征暂停", "知识、委托奖励和已清理区域自动保存。菜单撤离需站定3秒，受伤会打断；返营后主动休整。解开检修机关后，营地会开放直达该区域的通路。\n\n已清区域可单独重试：耗材照常消耗，击杀无经验、掉落或残魂，探索进度保留。重置整轮遭遇则重新开启全部战斗。", [
		{"title": "继续", "callback": close_modal},
		{"title": "装备与构筑", "callback": func(): equipment_requested.emit()},
		{"title": "返回营地", "callback": retreat_requested.emit},
		{"title": "重试本区（无击杀奖励）", "disabled": not practice_available.is_valid() or not practice_available.call(), "callback": func(): practice_requested.emit()},
		{"title": "重置遭遇，保留已学知识", "callback": func(): close_modal(); replay_requested.emit()},
	])

func show_journal() -> void:
	if journal_provider.is_valid():
		show_panel("探索日志", journal_provider.call(), [{"title": "元素关系：线索与验证", "callback": elements_requested.emit}, {"title": "实验路线与配置记录", "callback": trials_requested.emit}, {"title": "继续探索", "callback": close_modal}])
		return
	var text := "行动提示\n鼠标左键近战；右键或6使用火花；1震荡、3霜阵、5火阵需要探索学习。\n法阵内火花产生远程法术；新阵替换旧阵。J关闭日志。\n\n监狱路线\n营地 → 外院 → 火药库 → 重卫关隘 → 熔炉大厅\n可选支路：外院的军械档案、火药库的排水回廊。\n\n发现记录\n"
	for entry in progress.journal:
		text += "\n%s\n%s\n" % [entry.title, entry.text]
	if progress.journal.is_empty():
		text += "还没有发现记录。先阅读营地手记和外院入口的铭刻记录。"
	show_panel("探索日志", text, [{"title": "继续探索", "callback": close_modal}])
