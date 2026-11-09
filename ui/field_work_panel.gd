class_name FieldWorkPanel
extends CanvasLayer
## Live controls stay inside the viewport; only the explanation scrolls.
var text: Label
var bar: ProgressBar
var selector: OptionButton
var start_button: Button
var cancel_button: Button
var _titles: PackedStringArray=[]
var _panel: PanelContainer
var _scroll: ScrollContainer
func _ready() -> void:
	layer = GameUIStyle.LAYER_RUN + 1
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", GameUIStyle.panel_style(.96, 6, GameUIStyle.BORDER_STRONG))
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	text = Label.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_label(text, 13, GameUIStyle.TEXT_MAIN)
	_scroll.add_child(text)
	bar = ProgressBar.new()
	bar.max_value = 1
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameUIStyle.apply_progress(bar, GameUIStyle.GOLD, 8)
	box.add_child(bar)
	selector=OptionButton.new()
	selector.fit_to_longest_item=false
	selector.clip_text=true
	selector.custom_minimum_size.y=34
	box.add_child(selector)
	var row:=HBoxContainer.new()
	box.add_child(row)
	start_button=FrontierWidgets.button("开始作业",func(): pass)
	cancel_button=FrontierWidgets.button("取消",func(): pass)
	row.add_child(start_button)
	row.add_child(cancel_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var bottom := minf(136, viewport.y*.2)
	var width := minf(372, viewport.x-36)
	var height := minf(360, viewport.y-bottom-18)
	_panel.offset_left=-width-18; _panel.offset_right=-18
	_panel.offset_top=-height-bottom; _panel.offset_bottom=-bottom

func display(message: String, progress: float = -1.0) -> void:
	text.text = message
	bar.visible = progress >= 0
	bar.value = maxf(0, progress)
	start_button.text=InputBindings.label("interact")+"  开始作业"
	show()

func choices(methods: Array[FieldWorkMethod], selected: int, busy: bool, reason: String) -> void:
	var titles:=PackedStringArray()
	for method in methods: titles.append(method.title)
	if titles!=_titles:
		selector.clear()
		for title in titles: selector.add_item(title if title.length()<=24 else title.left(23)+"…")
		_titles=titles
	if selected<selector.item_count:
		selector.select(selected)
		selector.tooltip_text=titles[selected]
	selector.visible=not titles.is_empty() and not busy
	start_button.visible=not busy and not titles.is_empty()
	start_button.disabled=not reason.is_empty()
	start_button.tooltip_text=reason
