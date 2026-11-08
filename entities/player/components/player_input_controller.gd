class_name PlayerInputController
extends Node

var player: Player
var casting: PlayerCastingController
var _mouse_shortcuts: Dictionary={}
var _ui_click_pending := false
var _attack_suppressed := false
var _suppressed_sources: Dictionary={}
var _fresh_after_ui: Dictionary={}
var _focus: Node2D
var _focus_frame := -1
var _focus_origin := Vector2.INF
const INTERACT_RANGE := 80.0

func _init(actor: Player) -> void:
	player = actor
	casting = player.casting

func poll_universal_actions() -> Array[Action]:
	if player.ui_blocked or player.health_component.is_dead:
		return []

	var actions: Array[Action] = []
	var selecting:=is_instance_valid(player.material_wheel) and player.material_wheel.visible
	var tactical:=player.actor_context and player.actor_context.rules.tactical_combat
	var heavy:=tactical and not _attack_suppressed and Input.is_action_just_pressed("heavy_attack") and not selecting and not _pointer_over_interface()
	if tactical:
		for pair in [[Action.ActionType.GUARD,"guard"],[Action.ActionType.SPRINT,"sprint"]]:
			var state:=Action.new()
			state.action_type=pair[0]; state.source=player; state.direction=player.get_mouse_direction()
			state.params["held"]=Input.is_action_pressed(pair[1]) and not (pair[1]=="guard" and _pointer_over_interface() and not selecting)
			actions.append(state)
		if Input.is_action_just_pressed("drop_pack"):
			var drop:=Action.new(); drop.action_type=Action.ActionType.DROP_PACK; drop.source=player; actions.append(drop)
		if heavy:
			var hit:=Action.melee(player); hit.action_type=Action.ActionType.HEAVY_ATTACK; hit.direction=player.get_mouse_direction(); actions.append(hit)

	# 移动
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.05:
		actions.append(Action.move(input_dir, player))

	# 闪避
	if Input.is_action_just_pressed("dodge"):
		if selecting: player.material_wheel.close()
		actions.append(Action.dodge(input_dir if input_dir.length() > 0.1 else player.facing_direction, player))

	# 左键始终提出武器攻击，法术使用独立键位。
	if not selecting and not _attack_suppressed and Input.is_action_just_pressed("attack") and not _pointer_over_interface() and not heavy:
		var hit:=Action.melee(player)
		hit.direction=player.get_mouse_direction()
		actions.append(hit)

	# Every shortcut can carry a skill or an item. Input only proposes requests.
	for source in QuickslotLoadout.SOURCES:
		if selecting: continue
		var input_action:=action_for_source(source)
		_poll_shortcut_edges(actions,source,input_action)
	# 交互
	if not selecting and Input.is_action_just_pressed("interact"):
		actions.append(Action.interact(player))

	_ui_click_pending=false
	return actions

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_window().focus_exited.connect(_focus_lost)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if not player.ui_blocked and not get_tree().paused and not (is_instance_valid(player.material_wheel) and player.material_wheel.visible): _attack_suppressed=false
	# Global Input edges survive handled UI events. Preserve a genuinely new press
	# after closing a selector, without replaying its earlier selection/release.
	if event is InputEventKey or event is InputEventMouseButton:
		for source in QuickslotLoadout.SOURCES:
			var action:=action_for_source(source)
			if event.is_action_pressed(action) and not (event is InputEventKey and event.echo):
				if player.ui_blocked or get_tree().paused or is_instance_valid(player.material_wheel) and player.material_wheel.visible:
					_suppressed_sources[source]=true
				elif _suppressed_sources.has(source):
					_suppressed_sources.erase(source); _fresh_after_ui[source]=false
			elif event.is_action_released(action) and _fresh_after_ui.has(source): _fresh_after_ui[source]=true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		for source in _mouse_shortcuts.keys(): request_shortcut(source,false,true)

func source_held(source: String) -> bool:
	return not player.ui_blocked and not get_tree().paused and (bool(_mouse_shortcuts.get(source,false)) or Input.is_action_pressed(action_for_source(source)))

func request_shortcut(source: String,pressed: bool,mouse := false) -> void:
	if mouse:
		if not pressed and not _mouse_shortcuts.has(source): return
		if pressed: _mouse_shortcuts[source]=true; pointer_consumed()
		else: _mouse_shortcuts.erase(source)
	if player.ui_blocked or get_tree().paused or player.health_component.is_dead or is_instance_valid(player.material_wheel) and player.material_wheel.visible: return
	var actions: Array[Action]=[]
	_poll_shortcut(actions,source,pressed)
	for action in actions: resolve_action(action)

func _poll_shortcut(actions: Array[Action],source: String,pressed: bool) -> void:
	if is_instance_valid(player.material_wheel): player.material_wheel.remember_source(source)
	var entry:=player.skill_manager.shortcuts.binding(source)
	if entry.get("kind","")=="technique":
		if pressed:
			var request:=Action.new(); request.action_type=Action.ActionType.TECHNIQUE; request.source=player
			request.skill_id=entry.technique_id; request.skill_source=source; request.direction=player.get_mouse_direction()
			request.params={"binding_revision":player.skill_manager.shortcuts.revision(source),"release_enchantment":Input.is_key_pressed(KEY_SHIFT)}
			if request.params.release_enchantment:
				var context:=player.actor_context
				var uid:=str(context.items.equipped(context.id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
				request.params["enchantment_weapon_uid"]=uid
				request.params["enchantment_state"]=context.items.coating_state(uid)
			actions.append(request)
		return
	if entry.get("kind","")=="item":
		var definition:=ItemCatalog.default_catalog().definition(str(entry.item_id))
		if not definition: return
		if not pressed and not (definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.THROWABLE): return
		var request:=Action.new(); request.action_type=Action.ActionType.USE_ITEM; request.source=player
		request.skill_source=source; request.skill_id=str(entry.item_id); request.direction=player.get_mouse_direction()
		request.params={"binding":entry,"release":not pressed}
		actions.append(request); return
	if Input.is_action_pressed("guard"): return
	_poll_cast_edge(actions,source,pressed)

func _poll_cast_edge(actions: Array[Action], source: String, pressed: bool) -> void:
	if not _can_cast_source(source):
		return
	var released := not pressed
	var action := Action.cast(source, player.get_mouse_direction(), player)
	action.params["release"] = released
	var skill := _get_skill_for_source(source)
	var quick:=_quick_skill(skill)
	if quick and released: return
	action.params["quick_cast"] = quick
	action.cast_context = CastContext.at_position(player, CastContext.ground_point(player, player.get_global_mouse_position(), skill.cast_distance), skill) if skill.ground_targeted else CastContext.simple(player, action.direction, skill)
	action.cast_context.empower = Input.is_key_pressed(KEY_SHIFT)
	action.cast_context.selection=player.skill_manager.shortcuts.selection(source)
	action.cast_context.binding_revision=player.skill_manager.shortcuts.revision(source)
	actions.append(action)

func resolve_action(action: Action) -> void:
	if player.actor_context and player.actor_context.actions.active():
		player.actor_context.actions.try_action(action)
		return
	execute_action(action)

func execute_action(action: Action) -> void:
	if player.field_work:
		if action.action_type == Action.ActionType.INTERACT and player.field_work.interact(): return
		if action.action_type in [Action.ActionType.MOVE, Action.ActionType.DODGE, Action.ActionType.MELEE, Action.ActionType.CAST]:
			player.field_work.cancel("开始其他动作：作业取消")
			player.field_work.close_panel()
	# 统一验证（CAST 的验证在 CAST_RELEASE 分支内单独处理，CAST_PRESS 不验证）
	if action.action_type != Action.ActionType.CAST:
		if not ActionResolver.validate(player, action):
			return

	match action.action_type:
		Action.ActionType.MELEE:
			if player.skill_manager.combinations:
				player.skill_manager.combinations.cancel("近战：准备取消")
			casting.aiming_sources.clear()
			casting.hide_aim()
			player.state_machine.transition_to("attack")

		Action.ActionType.DODGE:
			if player.survival: player.survival.exert(.5)
			if player.skill_manager.combinations:
				player.skill_manager.combinations.cancel("闪避：准备取消")
			casting._cancel_charge()
			casting._cancel_channel()
			casting.aiming_sources.clear()
			casting.hide_aim()
			player.state_machine.transition_to("dodge")

		Action.ActionType.INTERACT:
			_try_interact(action.target,bool(action.params.get("targeted",false)))

		Action.ActionType.CAST:
			if action.params.get("release", false):
				# CAST_RELEASE — 验证后才执行
				if casting._charge_source_matches(action.skill_source):
					# 蓄力释放：取消蓄力，正常施放
					casting.aiming_sources.erase(action.skill_source)
					_cast_source(action.skill_source, action.cast_context)
					player.state_machine.transition_to("skill")
					if casting.aiming_sources.is_empty():
						casting.hide_aim()
					return
				if casting._channeling_source == action.skill_source:
					# 引导松开：停止引导
					casting._cancel_channel()
					casting.aiming_sources.erase(action.skill_source)
					if casting.aiming_sources.is_empty():
						casting.hide_aim()
					return
				if not ActionResolver.validate(player, action):
					# MP/冷却不足，清除瞄准但不执行
					casting.aiming_sources.erase(action.skill_source)
					if casting.aiming_sources.is_empty():
						casting.hide_aim()
					return
				if casting.aiming_sources.has(action.skill_source):
					casting.aiming_sources.erase(action.skill_source)
					_cast_source(action.skill_source, action.cast_context)
					player.state_machine.transition_to("skill")
				if casting.aiming_sources.is_empty():
					casting.hide_aim()
			else:
				if action.params.get("quick_cast",false):
					if ActionResolver.validate(player,action):
						_cast_source(action.skill_source,action.cast_context)
						player.state_machine.transition_to("skill")
					return
				# CAST_PRESS — 总是显示瞄准
				casting.aiming_sources[action.skill_source] = true
				var skill := _get_skill_for_source(action.skill_source)
				if skill:
					# 蓄力技能：进入蓄力状态
					if skill.cast_type == "charge":
						casting._begin_charge(action.skill_source, skill)
					# 引导技能：进入引导状态
					elif skill.cast_type == "channel":
						casting._begin_channel(action.skill_source, skill, action.cast_context.empower if action.cast_context else false)
					else:
						casting.show_aim(action.skill_source, skill)

func _can_cast_source(source: String) -> bool:
	return player.skill_manager.get_instance(source)!=null

func _get_skill_for_source(source: String) -> SkillData:
	var inst:=player.skill_manager.get_instance(source)
	return inst.data if inst else null

func _cast_source(source: String, context: CastContext = null) -> void:
	var skill := _get_skill_for_source(source)
	if not skill or (context and context.skill and context.skill != skill):
		casting.cancel_source(source)
		return
	if not context:
		context = CastContext.simple(player, player.get_mouse_direction(), skill)
	if casting._charge_skill and casting._charge_source_matches(source):
		if casting._charge_skill != skill or casting._charge_revision!=player.skill_manager.shortcuts.revision(source):
			casting.cancel_source(source)
			return
		context.charge_power = casting._charge_power
		casting._cancel_charge()
	player.skill_manager.use_source(source, player, context)

func request_interaction(target: Node2D) -> bool:
	if player.ui_blocked or player.health_component.is_dead or not is_instance_valid(target) or interaction_target(true)!=target: return false
	var action:=Action.interact(player); action.target=target; action.params["targeted"]=true
	if player.actor_context and player.actor_context.actions.active(): return player.actor_context.actions.try_action(action).accepted
	execute_action(action)
	return true

func _try_interact(expected: Node2D = null, targeted := false) -> void:
	if targeted and (not is_instance_valid(expected) or interaction_target(true)!=expected): return
	var balloon := DialogueBalloon.active
	if balloon != null and is_instance_valid(balloon) and balloon.has_method("advance"):
		balloon.advance()
		get_viewport().set_input_as_handled()
		return
	if DialogueBalloon.just_closed_frame == Engine.get_process_frames():
		get_viewport().set_input_as_handled()
		return

	var nearest := interaction_target(true)

	if nearest:
		var interactable := nearest.get_node_or_null("Interactable") as Interactable
		if interactable:
			interactable.interact(player)
			# 发射交互事件（供 Quest 等系统监听）
			if CombatEventBus.instance:
				var ev := CombatEvent.create(CombatEvent.Type.ON_INTERACT, player, nearest)
				CombatEventBus.instance.emit(ev)

func _unhandled_input(event: InputEvent) -> void:
	if player.ui_blocked or casting.aiming_sources.is_empty():
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		casting.cancel_all()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(player) and player.is_node_ready():
		player.cancel_active_input("窗口失焦：动作取消")


func interaction_target(refresh := false) -> Node2D:
	var frame := Engine.get_physics_frames()
	if not refresh and frame == _focus_frame and _focus_origin == player.global_position and is_instance_valid(_focus): return _focus
	_focus_frame=frame
	_focus_origin=player.global_position
	_focus=null
	var nearest:=INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Node2D or node.is_queued_for_deletion(): continue
		var distance:=player.global_position.distance_to(node.global_position)
		if distance<nearest:
			nearest=distance
			_focus=node
	return _focus

func _pointer_over_interface() -> bool:
	return _ui_click_pending or not _mouse_shortcuts.is_empty() or get_viewport().gui_get_hovered_control()!=null

func action_for_source(source: String) -> String:
	return InputBindings.action_for_source(source)

func _poll_universal_cast(actions: Array[Action],source: String,input_action: String) -> void:
	_poll_shortcut_edges(actions,source,input_action)

func shortcut_changed(source: String) -> void:
	_mouse_shortcuts.erase(source)
	casting.cancel_source(source)
	if not player.actor_context: return
	if player.actor_context.spray.source==source: player.actor_context.spray.stop()
	if player.actor_context.item_actions.input_source==source: player.actor_context.item_actions.cancel()

func _focus_lost() -> void:
	_fresh_after_ui.clear()
	for source in QuickslotLoadout.SOURCES: suppress_source(source)
	# Lost pointer releases cancel, never confirm a prepared throw or charged spell.
	for source in _mouse_shortcuts.keys(): shortcut_changed(source)
	casting.cancel_all()
	if player.actor_context:
		player.actor_context.item_actions.cancel()
		player.actor_context.spray.stop()

func _quick_skill(skill: SkillData) -> bool:
	return skill.operation_id=="disperse" or player.actor_context and player.actor_context.rules.modern_controls and ControlPreferences.quick_cast and skill.cast_type not in ["charge","channel"]

func _poll_shortcut_edges(actions: Array[Action],source: String,input_action: String) -> void:
	if _fresh_after_ui.has(source):
		var released: bool=_fresh_after_ui[source]
		_fresh_after_ui.erase(source)
		_poll_shortcut(actions,source,true)
		if released: _poll_shortcut(actions,source,false)
		return
	if _suppressed_sources.has(source):
		if not Input.is_action_pressed(input_action): _suppressed_sources.erase(source)
		return
	var pressed:=Input.is_action_just_pressed(input_action)
	var released:=Input.is_action_just_released(input_action)
	if pressed and released:
		# One physics frame may contain a complete tap. Preserve the chosen input
		# mode without duplicating casts or swallowing an ordinary item use.
		var inst:=player.skill_manager.get_instance(source)
		var entry:=player.skill_manager.shortcuts.binding(source)
		if entry.get("kind","") in ["item","technique"]:
			_poll_shortcut(actions,source,true)
			var definition:=ItemCatalog.default_catalog().definition(str(entry.get("item_id","")))
			if definition and definition.use_profile and definition.use_profile.kind==ItemUseDefinition.Kind.THROWABLE: _poll_shortcut(actions,source,false)
		else: _poll_shortcut(actions,source,inst!=null and _quick_skill(inst.data))
	elif pressed: _poll_shortcut(actions,source,true)
	elif released: _poll_shortcut(actions,source,false)

func suppress_source(source: String) -> void:
	_suppressed_sources[source]=true
func suppress_held_shortcuts() -> void:
	_fresh_after_ui.clear()
	for source in QuickslotLoadout.SOURCES:
		if Input.is_action_pressed(action_for_source(source)): suppress_source(source)
func pointer_consumed() -> void:
	_ui_click_pending=true
	# Handled GUI presses remain in global Input across physics frames. Keep
	# this press suppressed until a genuinely new gameplay press arrives.
	_attack_suppressed=true
