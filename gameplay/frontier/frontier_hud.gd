class_name FrontierHUD
extends CanvasLayer
var game: GrayriverGame
var tracker: Button
var interact: Button
var _focus: WeakRef
var belt: Array[Button] = []
var _belt_grid: GridContainer
var _clock := 0.0
const FOODS := ["ration","clean_water","tea","broth"]
const BELT_ACTIONS := ["quick_item_1","quick_item_2","quick_item_3","quick_item_4"]
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
	var status:=PanelContainer.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	status.offset_left=18; status.offset_right=278; status.offset_top=184; status.offset_bottom=266
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status.add_theme_stylebox_override("panel",GameUIStyle.surface_style())
	root.add_child(status)
	var actor_status:=preload("res://gameplay/foundation/ui/actor_status_view.tscn").instantiate() as ActorStatusView
	actor_status.context=game.player.actor_context
	status.add_child(actor_status)
	var prompt:=PanelContainer.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left=-210
	prompt.offset_right=210
	prompt.offset_top=-174
	prompt.offset_bottom=-138
	prompt.visible=false
	prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_stylebox_override("panel",GameUIStyle.surface_style())
	root.add_child(prompt)
	interact=FrontierWidgets.button("",_interact)
	interact.tooltip_text="点击与F交互相同；须在目标附近"
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
		var button:=Button.new()
		GameUIStyle.apply_button(button)
		button.gui_input.connect(_shortcut_mouse.bind(i))
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
	for i in range(4):
		var source: String=QuickslotLoadout.ITEM_SOURCES[i]
		var binding:=game.player.skill_manager.shortcuts.binding(source)
		var inst:=game.player.skill_manager.get_instance(source)
		var title: String=inst.data.display_name if inst else "空槽"
		var detail: String="K编组动作或物品"
		var amount: String=""
		var ready:=inst!=null
		if binding.get("kind","")=="item":
			var view:=QuickslotView.item_state(game.player,binding)
			title=view.title; detail=view.detail; ready=view.ready; amount="×%d"%view.count
		elif inst:
			var plan:=game.player.skill_manager.preview_source(source)
			detail=inst.data.description+"\n"+plan.reason; amount="%d MP"%plan.cost
		belt[i].text="%s %s\n%s"%[InputBindings.label(BELT_ACTIONS[i]),title,amount]
		belt[i].disabled=not ready or game.player.health_component.is_dead
		belt[i].tooltip_text="按键："+InputBindings.labels(BELT_ACTIONS[i])+"\n"+detail
	var goal:=game.guidance.tracked()
	var orienting := goal.is_empty()
	if orienting: goal = game.guidance.town_orientation()
	tracker.text="Tab 远征面板\n选择一个委托开始追踪"
	if not goal.is_empty():
		tracker.text=("镇中整备 · 靠近按 "+InputBindings.label("interact")+"\n" if orienting else "正在追踪\n")+goal.title
		var point:=game.guidance.route_target(goal)
		if point.is_finite():
			var delta_pos:=point-game.player.position
			var angle:=int(round(delta_pos.angle()/(PI/4)))
			var arrow: String=["→","↘","↓","↙","←","↖","↑","↗"][posmod(angle,8)]
			tracker.text+="\n"+arrow+" %.0f步%s"%[delta_pos.length()/32," · 先到遗迹出口" if game.region_id!=goal.region else ""]
		else: tracker.text+="\n先探索相关地点；地图不揭示未发现目标"
	var target:=game.player.input_controller.interaction_target()
	_focus=weakref(target) if is_instance_valid(target) else null
	interact.get_parent().visible=is_instance_valid(target) and not game.player.health_component.is_dead and not get_tree().paused
	if is_instance_valid(target):
		var title: String=target.title if "title" in target else target.enemy_name if target is Enemy else target.spec.title if target is SpellWorldObject else "调查"
		interact.text=InputBindings.label("interact")+"  "+title
		interact.tooltip_text="点击与"+InputBindings.label("interact")+"交互相同；须在目标附近"
func _interact() -> void:
	if get_tree().paused or not _focus: return
	var target:=_focus.get_ref() as Node2D
	if not game.player.input_controller.request_interaction(target): game.ui.notify("当前无法交互，请靠近目标或结束当前动作。")
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey and not event is InputEventMouseButton or event is InputEventKey and event.echo or game.ui.modal_locked: return
	if event.is_action_pressed("loot_all") and is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("frontier_page","")=="loot":
		game.hub.take_all(); get_viewport().set_input_as_handled(); return

func _shortcut_mouse(event: InputEvent,index: int) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		game.player.input_controller.request_shortcut(QuickslotLoadout.ITEM_SOURCES[index],event.pressed,true)
func use(index: int) -> void:
	if index>=0 and index<4: game.player.input_controller.request_shortcut(QuickslotLoadout.ITEM_SOURCES[index],true)
