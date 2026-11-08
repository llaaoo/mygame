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
var _pending_notices: Array[String]=[]
var progress: ExplorationProgress
var modal_locked := false
var journal_provider: Callable
var map_provider: Callable
var pause_provider: Callable
var practice_available: Callable
var material_action: Callable
var menu_action: Callable
var journal_action: Callable
var shortcut_action: Callable
var _modal_extent := Vector2(960,570)
var _heading_panel: PanelContainer
var _notice: PanelContainer
var _modal_panel: PanelContainer
var _terrain_label: Label
var _terrain_time := 0.0
var _survival_label: Label

func _ready() -> void:
	GameUIStyle.install_theme(get_window())
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = GameUIStyle.LAYER_RUN
	var panel := PanelContainer.new()
	_heading_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = 8
	panel.add_theme_stylebox_override("panel", GameUIStyle.quiet_panel(.25))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	heading = _label("余烬监狱", 18)
	objective = _label("", 12)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.max_lines_visible=1
	objective.modulate=GameUIStyle.TEXT_MUTED
	box.add_child(heading)
	box.add_child(objective)
	var footer := PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -214
	footer.offset_right = -18
	footer.offset_top = -68
	footer.offset_bottom = -18
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_stylebox_override("panel", GameUIStyle.quiet_panel(.35))
	add_child(footer)
	var menu:=Button.new()
	menu.text="Tab  远征菜单"
	menu.tooltip_text="鼠标进入装备、补给、技能和制作；Esc返回"
	GameUIStyle.apply_button(menu)
	menu.pressed.connect(show_menu)
	footer.add_child(menu)
	var needs_panel := PanelContainer.new()
	needs_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	needs_panel.offset_left = 20
	needs_panel.offset_right = 300
	needs_panel.offset_top = -214
	needs_panel.offset_bottom = -184
	needs_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	needs_panel.add_theme_stylebox_override("panel", GameUIStyle.quiet_panel(.35))
	add_child(needs_panel)
	_survival_label = _label("饱食100 · 饮水100 · 疲劳0", 12)
	_survival_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs_panel.add_child(_survival_label)
	var terrain := PanelContainer.new()
	terrain.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	terrain.offset_left = 18
	terrain.offset_right = 216
	terrain.offset_top = -326
	terrain.offset_bottom = -290
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain.add_theme_stylebox_override("panel", GameUIStyle.quiet_panel(.35))
	add_child(terrain)
	_terrain_label = _label("脚下 · 干地", 12)
	terrain.add_child(_terrain_label)
	_notice = PanelContainer.new()
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice.offset_left = -250
	_notice.offset_right = 250
	_notice.offset_top = 84
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_stylebox_override("panel", GameUIStyle.quiet_panel(.85))
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
	var actor:=get_tree().get_first_node_in_group("player") as Player
	var selecting:=actor and is_instance_valid(actor.material_wheel) and actor.material_wheel.visible
	_heading_panel.visible=not selecting
	_terrain_time += delta
	if _terrain_time >= .2:
		_terrain_time = 0
		_update_terrain()
	if not get_tree().paused:
		_message_time -= delta
		_notice.modulate.a=clampf(_message_time/.35,0,1)
		_notice.visible=_message_time>0 and not selecting
		if _message_time <= 0:
			message.text = ""
			_notice.hide()
			if not _pending_notices.is_empty(): notify(_pending_notices.pop_front())

func queue_notice(text: String) -> void:
	if text in _pending_notices: return
	if _pending_notices.size()>=5: _pending_notices.pop_front()
	_pending_notices.append(text)

func notify(text: String) -> void:
	_notice.show()
	message.text = text
	_message_time = 3.5

func set_survival_status(text: String) -> void:
	if _survival_label: _survival_label.tooltip_text=text

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	# An external loadout/inventory window owns its shortcuts and Escape.
	for owner in get_tree().get_nodes_in_group("modal_ui"):
		if owner!=modal and owner is CanvasLayer and owner.visible: return
	if not modal_locked and shortcut_action.is_valid() and shortcut_action.call(event.keycode):
		get_viewport().set_input_as_handled()
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
		elif material_action.is_valid():
			material_action.call()
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

func show_menu() -> void:
	if menu_action.is_valid(): menu_action.call()
	else: show_journal()

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		GameUIStyle.end_modal(modal)
		modal.queue_free()
	modal = null
	_modal_panel = null
	modal_locked = false

func show_panel(title: String, text: String, buttons: Array[Dictionary], locked: bool = false, extent := Vector2(960,570)) -> void:
	close_modal()
	_modal_extent = extent
	modal_locked = locked
	modal = CanvasLayer.new()
	modal.layer = GameUIStyle.LAYER_MODAL + 1
	modal.process_mode = Node.PROCESS_MODE_ALWAYS
	modal.add_to_group("modal_ui")
	modal.set_meta("close_request",close_modal)
	modal.set_meta("locked",locked)
	add_child(modal)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = GameUIStyle.modal_backdrop()
	modal.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_modal_panel = panel
	panel.name = "ContentPanel"
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.99, 2,GameUIStyle.PANEL_BORDER))
	backdrop.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var title_label := _label(title, 27)
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
	var content_row:=HBoxContainer.new()
	content_row.add_theme_constant_override("separation",24)
	content_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(content_row)
	var scroll := ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.custom_minimum_size = Vector2(0, 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content_row.add_child(scroll)
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
	var body_ref: WeakRef=weakref(body)
	scroll.resized.connect(func():
		var current:=body_ref.get_ref() as RichTextLabel
		if current: current.custom_minimum_size.x = maxf(1, scroll.size.x - 20))
	var button_host: Container=box
	if buttons.size()>3:
		var button_scroll:=ScrollContainer.new()
		button_scroll.name="ActionsScroll"
		button_scroll.custom_minimum_size.x=290
		button_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		button_scroll.follow_focus=true
		content_row.add_child(button_scroll)
		var list:=VBoxContainer.new()
		list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation",6)
		button_scroll.add_child(list)
		button_host=list
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
		if not button.disabled and (first_button == null or entry.get("focused",false)): first_button = button
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
	var extent := Vector2(minf(_modal_extent.x, viewport.x - 48), minf(_modal_extent.y, viewport.y - 48))
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
	_terrain_label.text = title+" · "+detail
	_terrain_label.tooltip_text="脚下介质："+title+"\n"+detail
	_terrain_label.get_parent().visible=state!="dry"
	if player is Player and player.survival:
		var needs: SurvivalNeeds=player.survival.needs
		var warnings: Array[String]=[]
		if needs.nutrition<=20: warnings.append("饥饿")
		if needs.hydration<=20: warnings.append("缺水")
		if needs.fatigue>=60: warnings.append("疲惫")
		_survival_label.text=" · ".join(warnings)+"   N 查看补给"
		_survival_label.get_parent().visible=not warnings.is_empty()
	else: _survival_label.get_parent().hide()
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
	if journal_action.is_valid():
		journal_action.call()
		return
	if journal_provider.is_valid():
		show_panel("探索日志", journal_provider.call(), [{"title": "元素关系：线索与验证", "callback": elements_requested.emit}, {"title": "实验路线与配置记录", "callback": trials_requested.emit}, {"title": "继续探索", "callback": close_modal}])
		return
	var text := "行动提示\n左键攻击，右键格挡；Q/E/R与1—0独立快捷槽，K编组动作或物品。\n法阵内火花产生远程法术；新阵替换旧阵。J关闭日志。\n\n监狱路线\n营地 → 外院 → 火药库 → 重卫关隘 → 熔炉大厅\n可选支路：外院的军械档案、火药库的排水回廊。\n\n发现记录\n"
	for entry in progress.journal:
		text += "\n%s\n%s\n" % [entry.title, entry.text]
	if progress.journal.is_empty():
		text += "还没有发现记录。先阅读营地手记和外院入口的铭刻记录。"
	show_panel("探索日志", text, [{"title": "继续探索", "callback": close_modal}])

func show_view(title: String, content: Control) -> void:
	show_panel(title,"",[],false,Vector2(1080,660))
	var scroll := _modal_panel.find_child("BodyScroll",true,false) as ScrollContainer
	var old := scroll.get_child(0)
	scroll.remove_child(old)
	old.queue_free()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
