class_name FieldWorkPanel
extends CanvasLayer
## Live controls stay inside the viewport; only the explanation scrolls.
var text: Label
var heading: Label
var bar: ProgressBar
var selector: OptionButton
var start_button: Button
var cancel_button: Button
var _titles: PackedStringArray=[]
var _panel: PanelContainer
var _scroll: ScrollContainer
var _summary: Label
var _preparation: Label
var _cost: Label
var _reason: Label
var details_toggle: CheckButton
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
	heading=FoundationWidgets.label("现场作业",18)
	box.add_child(heading)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	var content:=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	_summary=FoundationWidgets.label("",15); content.add_child(_summary)
	_preparation=FoundationWidgets.label("",13,true); content.add_child(_preparation)
	_cost=FoundationWidgets.label("",13); content.add_child(_cost)
	_reason=FoundationWidgets.label("",13,true); content.add_child(_reason)
	text = FoundationWidgets.label("",13,true)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text)
	details_toggle=CheckButton.new(); details_toggle.name="WorkDetailsToggle"; details_toggle.text="查看详细规则"
	details_toggle.toggled.connect(func(expanded: bool): text.visible=expanded; _layout())
	box.add_child(details_toggle)
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
	GameUIStyle.primary(start_button)
	row.add_child(start_button)
	row.add_child(cancel_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var bottom := minf(136, viewport.y*.2)
	var width := minf(372, viewport.x-36)
	var height := minf(maxf(_panel.get_combined_minimum_size().y,400 if text.visible else 320), viewport.y-bottom-18)
	_panel.offset_left=-width-18; _panel.offset_right=-18
	_panel.offset_top=-height-bottom; _panel.offset_bottom=-bottom

func display(message: String, progress: float = -1.0) -> void:
	if not visible: UIMotion.enter(_panel)
	var split:=message.find("\n")
	heading.text=message.left(split) if split>=0 else "现场作业"
	text.text=message.substr(split+1) if split>=0 else message
	for label in [_summary,_preparation,_cost,_reason]: label.hide()
	details_toggle.hide(); text.show(); _scroll.show()
	bar.visible = progress >= 0
	bar.value = maxf(0, progress)
	start_button.text=InputBindings.label("interact")+"  开始作业"
	_layout(); show()

func present_work(title: String,summary: String,seconds: float,cost: String,reason: String,guide: String,progress := -1.0) -> void:
	if not visible: UIMotion.enter(_panel)
	if heading.text!=title: details_toggle.set_pressed_no_signal(false)
	heading.text=title
	_summary.text=summary
	_preparation.text=("剩余准备 %.1f 秒" if progress>=0 else "操作准备 %.1f 秒 · 可中断")%maxf(0,seconds)
	_cost.text="消耗："+(cost if not cost.is_empty() else "无需材料")
	_reason.text="无法开始："+reason if not reason.is_empty() else "准备完成后结算 · 世界持续运行"
	_reason.add_theme_color_override("font_color",GameUIStyle.GOLD if not reason.is_empty() else GameUIStyle.TEXT_MUTED)
	for label in [_summary,_preparation,_cost,_reason]: label.show()
	text.text=guide
	details_toggle.visible=not guide.is_empty()
	text.visible=details_toggle.visible and details_toggle.button_pressed
	_scroll.show()
	bar.visible=progress>=0; bar.value=maxf(0,progress)
	start_button.text=InputBindings.label("interact")+"  开始作业"
	_layout(); show()

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
