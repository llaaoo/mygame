class_name FrontierHUD
extends CanvasLayer
var game: GrayriverGame
var tracker: Button
var time_label: Label
var interact: Button
var _focus: WeakRef
var belt: Array[Button] = []
var _belt_grid: GridContainer
var _clock := 0.0
var _binding_revision := -1
var _loadout_hint := ""
var _journal_hint := ""
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
	tracker.offset_top=24
	tracker.offset_bottom=116
	tracker.alignment=HORIZONTAL_ALIGNMENT_LEFT
	tracker.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	tracker.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
	GameUIStyle.apply_font_size(tracker,14)
	root.add_child(tracker)
	time_label=FoundationWidgets.label("",13,true)
	time_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	time_label.offset_left=-276; time_label.offset_right=-18
	time_label.offset_top=4; time_label.offset_bottom=24
	root.add_child(time_label)
	var prompt:=PanelContainer.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left=-210
	prompt.offset_right=210
	prompt.offset_top=-188
	prompt.offset_bottom=-148
	prompt.visible=false
	prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	prompt.add_theme_stylebox_override("panel",GameUIStyle.quiet_panel(.65))
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
		button.custom_minimum_size=Vector2(62,44)
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",22)
		button.tooltip_text=SurvivalCatalog.FOODS[FOODS[i]].text
		row.add_child(button)
		belt.append(button)
func _process(delta: float) -> void:
	_clock-=delta
	if _clock>0 or not game.ready_for_play: return
	_clock=.15
	if _binding_revision!=InputBindings.revision:
		_binding_revision=InputBindings.revision
		_loadout_hint=InputBindings.menu_help("K编组动作或物品")
		_journal_hint=InputBindings.menu_help("旅程  /  J\n选择要追踪的委托")
	time_label.text=WorldTime.instance.stamp()
	tracker.disabled=is_instance_valid(game.ui.modal)
	var selecting:=is_instance_valid(game.player.material_wheel) and game.player.material_wheel.visible
	tracker.visible=not selecting
	_belt_grid.visible=not game.player.field_work.panel.visible
	for i in range(4):
		var source: String=QuickslotLoadout.ITEM_SOURCES[i]
		var binding:=game.player.skill_manager.shortcuts.binding(source)
		var inst:=game.player.skill_manager.get_instance(source)
		var title: String=inst.data.display_name if inst else "空槽"
		var detail: String=_loadout_hint
		var amount: String=""
		var ready:=inst!=null
		if binding.get("kind","")=="technique":
			var view:=QuickslotView.technique_state(game.player,binding)
			title=view.title; detail=view.detail; ready=view.ready; amount="%.0f体"%view.cost
			belt[i].icon=GameUIStyle.icon("swords")
		elif binding.get("kind","")=="item":
			var view:=QuickslotView.item_state(game.player,binding)
			title=view.title; detail=view.detail; ready=view.ready; amount="×%d"%view.count
			belt[i].icon=InterfaceIcons.item(ItemCatalog.default_catalog().definition(str(binding.item_id)))
		elif inst:
			var plan:=game.player.skill_manager.preview_source(source)
			detail=inst.data.description+"\n"+plan.reason; amount="%d"%plan.cost
			belt[i].icon=InterfaceIcons.skill(inst.data)
		else: belt[i].icon=null
		belt[i].text="%s  %s"%[InputBindings.label(BELT_ACTIONS[i]),amount]
		belt[i].disabled=not ready or game.player.health_component.is_dead
		belt[i].tooltip_text="按键："+InputBindings.labels(BELT_ACTIONS[i])+"\n"+title+"\n"+detail
	var goal:=game.guidance.tracked()
	var orienting := goal.is_empty()
	if orienting: goal = game.guidance.town_orientation()
	tracker.text=_journal_hint
	if not goal.is_empty():
		tracker.text=("镇中整备\n" if orienting else "追踪委托\n")+goal.title
		var point:=game.guidance.route_target(goal)
		if point.is_finite():
			var delta_pos:=point-game.player.position
			var angle:=int(round(delta_pos.angle()/(PI/4)))
			var arrow: String=["→","↘","↓","↙","←","↖","↑","↗"][posmod(angle,8)]
			tracker.text+="\n"+arrow+" %.0f步%s"%[delta_pos.length()/32," · 先到遗迹出口" if game.region_id!=goal.region else ""]
		else: tracker.text+="\n先探索相关地点；地图不揭示未发现目标"
	var target:=game.player.input_controller.interaction_target()
	_focus=weakref(target) if is_instance_valid(target) else null
	var physical:=game.player.actor_context.actions
	var fighting:=physical.mode in ["attack","dodge","stagger"] or physical.guarding or physical.counter_remaining>0
	interact.get_parent().visible=not fighting and is_instance_valid(target) and not game.player.health_component.is_dead and not get_tree().paused and not selecting and game.player.casting.aimed_source().is_empty() and not game.player.skill_manager.combinations.is_busy()
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
