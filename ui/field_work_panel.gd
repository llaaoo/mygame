class_name FieldWorkPanel
extends CanvasLayer
## Live work controls: pointer and keyboard share the same domain operations.
var text: Label
var bar: ProgressBar
var selector: OptionButton
var start_button: Button
var cancel_button: Button
var _titles: PackedStringArray=[]
func _ready() -> void:
	layer = GameUIStyle.LAYER_RUN + 1
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -390
	panel.offset_right = -18
	panel.offset_top = -454
	panel.offset_bottom = -136
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.96, 6, GameUIStyle.BORDER_STRONG))
	add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	text = Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_label(text, 13, GameUIStyle.TEXT_MAIN)
	box.add_child(text)
	bar = ProgressBar.new()
	bar.max_value = 1
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_progress(bar, GameUIStyle.GOLD, 8)
	box.add_child(bar)
	selector=OptionButton.new()
	selector.custom_minimum_size.y=34
	box.add_child(selector)
	var row:=HBoxContainer.new()
	box.add_child(row)
	start_button=FrontierWidgets.button("F  开始作业",func(): pass)
	cancel_button=FrontierWidgets.button("取消",func(): pass)
	row.add_child(start_button)
	row.add_child(cancel_button)
	hide()

func display(message: String, progress: float = -1.0) -> void:
	text.text = message
	bar.visible = progress >= 0
	bar.value = maxf(0, progress)
	show()

func choices(methods: Array[FieldWorkMethod], selected: int, busy: bool, reason: String) -> void:
	var titles:=PackedStringArray()
	for method in methods: titles.append(method.title)
	if titles!=_titles:
		selector.clear()
		for title in titles: selector.add_item(title)
		_titles=titles
	if selected<selector.item_count: selector.select(selected)
	selector.visible=not titles.is_empty() and not busy
	start_button.visible=not busy and not titles.is_empty()
	start_button.disabled=not reason.is_empty()
	start_button.tooltip_text=reason
