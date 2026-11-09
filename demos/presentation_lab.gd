class_name PresentationLab
extends AnimationSandbox
## Controlled staging of existing content; all work, costs, knowledge checks and saves stay real.
var sites: Dictionary={}
var lab_status: Label
func _prepare_demo() -> void:
	await super._prepare_demo()
	# Explicit demo knowledge and materials, kept in the inherited memory repository.
	progress.claims["valley.bridge_beams"]=true
	survival.supplies.grant({"sap":2,"charcoal":1,"grain":2})
	region_changed.connect(_stage_lab)
	_stage_lab(region_id)
func _build_demo_controls() -> void:
	var layer:=CanvasLayer.new(); layer.layer=130; add_child(layer)
	_demo_panel=PanelContainer.new(); _demo_panel.position=Vector2(235,8); _demo_panel.size=Vector2(680,138)
	_demo_panel.add_theme_stylebox_override("panel",GameUIStyle.panel_style(.95)); layer.add_child(_demo_panel)
	var box:=VBoxContainer.new(); _demo_panel.add_child(box)
	box.add_child(FoundationWidgets.label("04 整体游戏表现",18))
	box.add_child(FoundationWidgets.label("既有采集点、柴灶、取水点与机关移位展示；材料/知识为演示预设，奖励、耗材和计时照常。",12,true))
	var views:=HBoxContainer.new(); box.add_child(views)
	views.add_child(FoundationWidgets.button("日景对照",_preview_hour.bind(12.0)))
	views.add_child(FoundationWidgets.button("夜景对照",_preview_hour.bind(23.0)))
	views.add_child(FoundationWidgets.button("恢复真实时刻",_preview_hour.bind(-1.0)))
	views.add_child(FoundationWidgets.button("减少动态效果",_motion_toggle))
	var targets:=HBoxContainer.new(); box.add_child(targets)
	for pair in [["forage","靠近采集点"],["hearth","靠近柴灶"],["water","靠近取水点"],["puzzle","靠近机关"]]:
		targets.add_child(FoundationWidgets.button(pair[1],_approach.bind(pair[0])))
	var routes:=HBoxContainer.new(); box.add_child(routes)
	routes.add_child(FoundationWidgets.button("表现设置",_settings))
	routes.add_child(FoundationWidgets.button("重置本演示",func(): get_tree().reload_current_scene()))
	routes.add_child(FoundationWidgets.button("角色动画",func(): get_tree().change_scene_to_file("res://demos/animation_gallery.tscn")))
	routes.add_child(FoundationWidgets.button("返回正式旅程",func(): get_tree().change_scene_to_file("res://grayriver.tscn")))
	lab_status=FoundationWidgets.label("F交互 → 选择方式 → 开始；采集约2秒、清障架设约4秒。F5/F9仅本演示内存。",12,true); box.add_child(lab_status)
func _stage_lab(_id: String) -> void:
	sites.clear()
	for node in region_root.get_children():
		if node is ExplorationInteractable and node.has_meta("survival_station"):
			var spec:=node.get_meta("survival_station") as SurvivalStationData
			var point:=Vector2.ZERO
			if spec.id=="river.herb": sites.forage=node; point=Vector2(-4120,900)
			elif spec.id=="river.stove": sites.hearth=node; point=Vector2(-3880,900)
			elif spec.id=="river.well": sites.water=node; point=Vector2(-4120,1050)
			else: continue
			node.position=point
		elif node is SpellWorldObject and node.spec.id=="river.bridge_fixed": sites.puzzle=node; node.position=Vector2(-3880,1050)
	player.position=Vector2(-4000,900); player.get_node("Camera2D").zoom=Vector2(1.4,1.4); player.get_node("Camera2D").reset_smoothing()
func _approach(id: String) -> void:
	if not sites.has(id) or not is_instance_valid(sites[id]): return
	ui.close_modal(); player.cancel_active_input("演示定位"); player.actor_context.actions.cancel("presentation_demo")
	player.position=sites[id].position+Vector2(-52,15); player.get_node("Camera2D").reset_smoothing()
	ui.notify("演示定位到既有设施；按F亲手操作。")
func _preview_hour(value: float) -> void:
	if presentation and presentation.environment:
		presentation.environment.preview_hour=value
		lab_status.text="仅视觉时刻对照，不改游戏时钟："+("真实时刻" if value<0 else "日景" if value==12 else "夜景")+" · F交互，Tab菜单继续模拟。"
func _motion_toggle() -> void:
	PresentationPreferences.set_option("reduced_motion",not PresentationPreferences.value("reduced_motion"))
	lab_status.text="减少动态效果："+("开" if PresentationPreferences.value("reduced_motion") else "关")+"；实际采集、机关与战斗照常推进。"
func _settings() -> void:
	ui.show_view("表现偏好",PresentationSettings.new())

