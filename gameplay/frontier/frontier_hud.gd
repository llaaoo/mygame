class_name FrontierHUD
extends CanvasLayer
var game: GrayriverGame
var tracker: Button
var interact: Label
var belt: Array[Button] = []
var _belt_grid: GridContainer
var _clock := 0.0
const FOODS := ["ration","clean_water","tea","broth"]
const KEYS := [KEY_7,KEY_8,KEY_9,KEY_0]
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	layer=GameUIStyle.LAYER_TRACKER
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	tracker=FrontierWidgets.button("选择要追踪的委托",func(): game.hub.open("quests"))
	tracker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tracker.offset_left=-276
	tracker.offset_right=-18
	tracker.offset_top=20
	tracker.offset_bottom=122
	root.add_child(tracker)
	var prompt:=PanelContainer.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left=-210
	prompt.offset_right=210
	prompt.offset_top=-174
	prompt.offset_bottom=-138
	prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_stylebox_override("panel",GameUIStyle.surface_style())
	root.add_child(prompt)
	interact=FrontierWidgets.label("",13)
	interact.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(interact)
	var row:=GridContainer.new()
	row.columns=2
	_belt_grid=row
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	row.offset_left=-150
	row.offset_right=-18
	row.offset_top=-162
	row.offset_bottom=-76
	root.add_child(row)
	for i in range(4):
		var button:=FrontierWidgets.button("",use.bind(i))
		button.custom_minimum_size.x=60
		button.tooltip_text=SurvivalCatalog.FOODS[FOODS[i]].text
		row.add_child(button)
		belt.append(button)
func _process(delta: float) -> void:
	_clock-=delta
	if _clock>0 or not game.ready_for_play: return
	_clock=.15
	tracker.disabled=is_instance_valid(game.ui.modal)
	_belt_grid.visible=not game.player.field_work.panel.visible
	interact.get_parent().visible=false
	for i in range(4):
		var count:=game.survival.supplies.count(FOODS[i])
		belt[i].text="%s %s\n×%d"%[["7","8","9","0"][i],["食","水","茶","汤"][i],count]
		belt[i].disabled=count==0 or game.player.health_component.is_dead
	var goal:=game.guidance.tracked()
	tracker.text="Tab 远征面板\n选择一个委托开始追踪" if goal.is_empty() else "正在追踪\n"+goal.title
	if not goal.is_empty():
		var point:=game.guidance.route_target(goal)
		if point.is_finite():
			var delta_pos:=point-game.player.position
			var angle:=int(round(delta_pos.angle()/(PI/4)))
			var arrow: String=["→","↘","↓","↙","←","↖","↑","↗"][posmod(angle,8)]
			tracker.text+="\n"+arrow+" %.0f步%s"%[delta_pos.length()/32," · 先到遗迹出口" if game.region_id!=goal.region else ""]
		else: tracker.text+="\n先探索相关地点；地图不揭示未发现目标"
	var target:=game.player.input_controller.interaction_target()
	interact.get_parent().visible=is_instance_valid(target) and not game.player.health_component.is_dead and not get_tree().paused
	if is_instance_valid(target):
		var title: String=target.title if "title" in target else target.enemy_name if target is Enemy else target.spec.title if target is SpellWorldObject else "调查"
		interact.text="E  "+title
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or game.ui.modal_locked: return
	if event.keycode==KEY_F and is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("frontier_page","")=="loot":
		game.hub.take_all()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and event.keycode in KEYS:
		use(KEYS.find(event.keycode))
		get_viewport().set_input_as_handled()
func use(index: int) -> void:
	if index<0 or index>=4 or get_tree().paused or game.player.health_component.is_dead or game.player.ui_blocked or game.player.field_work.is_busy(): return
	if game.survival.supplies.count(FOODS[index])>0: game.survival.begin_eating(FOODS[index])
