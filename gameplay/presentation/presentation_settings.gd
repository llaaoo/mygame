class_name PresentationSettings
extends VBoxContainer
func _ready() -> void:
	add_child(FoundationWidgets.label("表现选项立即生效，独立保存于偏好文件；不改变世界速度、命中或实际资源。",13,true))
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
