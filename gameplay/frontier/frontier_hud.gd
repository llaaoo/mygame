class_name FrontierHUD
extends CanvasLayer
var game: GrayriverGame
var tracker: Button
var time_label: Label
var interact: Button
var _focus: WeakRef
var _clock := 0.0
var _binding_revision := -1
var _loadout_hint := ""
var _journal_hint := ""
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	layer=GameUIStyle.LAYER_TRACKER
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	tracker=FrontierWidgets.button("选择要追踪的委托",_open_tracker)
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
	var preparation:=game.guidance.journey.town_goal()
	var goal:=preparation if not preparation.is_empty() else game.guidance.tracked()
	var orienting: bool = goal.is_empty() or bool(goal.get("journey",false))
	if goal.is_empty(): goal = game.guidance.town_orientation()
	tracker.text=_journal_hint
	if not goal.is_empty():
		tracker.text=("镇中整备\n" if orienting else "追踪委托\n")+goal.title
		var point:=game.guidance.route_target(goal)
		if not goal.get("navigate",true): pass
		elif point.is_finite():
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

func _open_tracker() -> void:
	if not game.guidance.journey.town_goal().is_empty(): game.hub.open_journey()
	else: game.hub.open("quests")
