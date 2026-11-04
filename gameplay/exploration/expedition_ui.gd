class_name ExpeditionUI
extends CanvasLayer

signal travel_requested(destination: String)
signal replay_requested
signal materials_requested

var heading: Label
var objective: Label
var message: Label
var modal: CanvasLayer
var _message_time := 0.0
var progress: ExplorationProgress
var modal_locked := false
var journal_provider: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = GameUIStyle.LAYER_RUN
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = 8
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style())
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	heading = _label("余烬监狱", 20)
	objective = _label("", 12)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	box.add_child(objective)
	var controls := _label("左键近战 · 右键/6火花 · 空格闪避 · E交互 · Shift消耗恩赐 · J日志 · Esc暂停", 11)
	box.add_child(controls)
	message = _label("", 15)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.position = Vector2(-270, -190)
	message.size = Vector2(540, 70)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUIStyle.apply_label(label, size, GameUIStyle.TEXT_MAIN)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _process(delta: float) -> void:
	if not get_tree().paused:
		_message_time -= delta
		if _message_time <= 0:
			message.text = ""

func notify(text: String) -> void:
	message.text = text
	_message_time = 5.0

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
	elif event.keycode == KEY_M:
		if modal_locked:
			return
		if is_instance_valid(modal):
			close_modal()
		else:
			materials_requested.emit()
		get_viewport().set_input_as_handled()

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		GameUIStyle.end_modal(modal)
		modal.queue_free()
	modal = null
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
	panel.position = Vector2(-310, -230)
	panel.custom_minimum_size = Vector2(620, 460)
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(0.99, 8))
	backdrop.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(_label(title, 24))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(570, 270)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var body := RichTextLabel.new()
	body.fit_content = true
	body.custom_minimum_size.x = 550
	body.text = text
	body.add_theme_font_size_override("normal_font_size", 15)
	scroll.add_child(body)
	var button_host: Container = box
	if buttons.size() > 3:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		if buttons.size() > 6:
			var button_scroll := ScrollContainer.new()
			button_scroll.custom_minimum_size.y = 145
			box.add_child(button_scroll)
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button_scroll.add_child(grid)
		else:
			box.add_child(grid)
		button_host = grid
	for entry in buttons:
		var button := Button.new()
		button.text = entry.title
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = bool(entry.get("disabled", false))
		GameUIStyle.apply_button(button)
		button.pressed.connect(entry.callback)
		button_host.add_child(button)
	GameUIStyle.begin_modal(modal)

func show_pause() -> void:
	show_panel("远征暂停", "知识、委托奖励和已清理区域自动保存。返回营地可以恢复，未清理区域的敌人会重新出现。\n\n同一动作在火阵与霜阵中产生不同结果。J日志可查看已学法术组合、区域状态、水路选择和委托进度。", [
		{"title": "继续", "callback": close_modal},
		{"title": "返回营地", "callback": func(): close_modal(); travel_requested.emit("camp")},
		{"title": "重置遭遇，保留已学知识", "callback": func(): close_modal(); replay_requested.emit()},
	])

func show_journal() -> void:
	if journal_provider.is_valid():
		show_panel("探索日志", journal_provider.call(), [{"title": "继续探索", "callback": close_modal}])
		return
	var text := "行动提示\n鼠标左键近战；右键或6使用火花；1震荡、3霜阵、5火阵需要探索学习。\n法阵内火花产生远程法术；新阵替换旧阵。J关闭日志。\n\n监狱路线\n营地 → 外院 → 火药库 → 重卫关隘 → 熔炉大厅\n可选支路：外院的军械档案、火药库的排水回廊。\n\n发现记录\n"
	for entry in progress.journal:
		text += "\n%s\n%s\n" % [entry.title, entry.text]
	if progress.journal.is_empty():
		text += "还没有发现记录。先阅读营地手记和外院入口的铭刻记录。"
	show_panel("探索日志", text, [{"title": "继续探索", "callback": close_modal}])
