class_name PresentationSettings
extends VBoxContainer
func _ready() -> void:
	add_child(FoundationWidgets.label("表现选项立即生效，独立保存于偏好文件；不改变世界速度、命中或实际资源。",13,true))
	add_child(FoundationWidgets.label("界面字号（不缩放世界或改变镜头）",13))
	var sizes:=HBoxContainer.new();sizes.name="TextScale"
	var group:=ButtonGroup.new()
	for scale in [1.0,1.1,1.25]:
		var button:=FoundationWidgets.button("%d%%"%roundi(scale*100),_text_size.bind(scale,sizes))
		button.toggle_mode=true;button.button_group=group
		button.set_meta("text_scale",scale)
		button.button_pressed=is_equal_approx(float(PresentationPreferences.value("text_scale")),scale)
		sizes.add_child(button)
	add_child(sizes)
	for pair in [["reduced_motion","减少动态效果"],["camera_feedback","镜头受击反馈"]]:
		var toggle:=CheckButton.new(); toggle.text=pair[1]; toggle.button_pressed=PresentationPreferences.value(pair[0])
		toggle.toggled.connect(_toggle.bind(pair[0],toggle)); add_child(toggle)
	var label:=FoundationWidgets.label("特效密度（只影响装饰，不隐藏危险范围）",13); add_child(label)
	var quality:=OptionButton.new(); quality.name="EffectsQuality"
	for title in ["低","标准","高"]: quality.add_item(title)
	quality.select(int(PresentationPreferences.value("effects_quality"))); quality.item_selected.connect(func(index: int): PresentationPreferences.set_option("effects_quality",index))
	add_child(quality)
	for key in ["world_volume","ui_volume"]:
		add_child(FoundationWidgets.label("世界音效音量" if key=="world_volume" else "界面音效音量",13))
		var volume:=HSlider.new(); volume.min_value=0; volume.max_value=1; volume.step=.05; volume.value=PresentationPreferences.value(key)
		volume.value_changed.connect(func(value: float): PresentationPreferences.set_option(key,value)); add_child(volume)
func _toggle(enabled: bool,key: String,toggle: CheckButton) -> void:
	if not PresentationPreferences.set_option(key,enabled): toggle.set_pressed_no_signal(not enabled)
func _text_size(value: float,row: HBoxContainer) -> void:
	GameUIStyle.set_text_scale(value,get_window())
	for button in row.get_children():
		button.set_pressed_no_signal(is_equal_approx(float(PresentationPreferences.value("text_scale")),float(button.get_meta("text_scale"))))
