class_name PlayerInputController
extends Node

var player: Player
var casting: PlayerCastingController
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
	var tactical:=player.actor_context and player.actor_context.rules.tactical_combat
	var heavy:=tactical and Input.is_action_just_pressed("heavy_attack") and not _pointer_over_interface()
	if tactical:
		for pair in [[Action.ActionType.GUARD,"guard"],[Action.ActionType.SPRINT,"sprint"]]:
			var state:=Action.new()
			state.action_type=pair[0]; state.source=player; state.direction=player.get_mouse_direction()
			state.params["held"]=Input.is_action_pressed(pair[1])
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
		actions.append(Action.dodge(input_dir if input_dir.length() > 0.1 else player.facing_direction, player))

	# 近战（左键 = 无左手技能时直接近战）
	if Input.is_action_just_pressed("attack") and not player.skill_manager.has_left_spell() and not _pointer_over_interface() and not heavy:
		var hit:=Action.melee(player)
		hit.direction=player.get_mouse_direction()
		actions.append(hit)

	# 技能（左手/右手/快捷键1-6）
	for pair in [["left", "attack"], ["right", "skill"]]:
		if heavy and pair[0]=="left": continue
		_poll_universal_cast(actions, pair[0], pair[1])
	for i in range(SkillManager.MAX_SLOTS):
		_poll_universal_cast(actions, "slot_%d" % i, "skill_%d" % (i + 1))

	# 交互
	if Input.is_action_just_pressed("interact"):
		actions.append(Action.interact(player))

	return actions

func _poll_universal_cast(actions: Array[Action], source: String, input_action: String) -> void:
	if source in ["left","right"] and _pointer_over_interface() and not Input.is_action_just_released(input_action): return
	if not _can_cast_source(source):
		return
	var pressed := Input.is_action_just_pressed(input_action)
	var released := Input.is_action_just_released(input_action)
	if not pressed and not released:
		return
	# A UI click has no matching cast press; its release must not cancel an item action.
	if released and not casting.aiming_sources.has(source) and casting._channeling_source!=source and not casting._charge_source_matches(source): return
	var action := Action.cast(source, player.get_mouse_direction(), player)
	action.params["release"] = released
	var skill := _get_skill_for_source(source)
	var quick := player.actor_context and player.actor_context.rules.modern_controls and ControlPreferences.quick_cast and skill.cast_type not in ["charge","channel"]
	if skill.operation_id=="disperse": quick=true
	if quick and released: return
	action.params["quick_cast"] = quick
	action.cast_context = CastContext.at_position(player, CastContext.ground_point(player, player.get_global_mouse_position(), skill.cast_distance), skill) if skill.ground_targeted else CastContext.simple(player, action.direction, skill)
	action.cast_context.empower = Input.is_key_pressed(KEY_SHIFT)
	actions.append(action)

func resolve_action(action: Action) -> void:
	if player.actor_context and player.actor_context.actions.active() and not action.params.get("authorized",false):
		player.actor_context.actions.try_action(action)
		return
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
			_try_interact()

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
						casting._begin_channel(action.skill_source, skill)
					else:
						casting.show_aim(action.skill_source, skill)

func _can_cast_source(source: String) -> bool:
	match source:
		"left":  return player.skill_manager.has_left_spell()
		"right": return player.skill_manager.has_right_spell()
		_:
			var idx := source.trim_prefix("slot_").to_int()
			var inst: SkillInstance = player.skill_manager.get_slot(idx)
			return inst != null and inst.data != null

func _get_skill_for_source(source: String) -> SkillData:
	var sm = player.skill_manager
	match source:
		"left":  return sm.left_hand.data if sm.left_hand else null
		"right": return sm.right_hand.data if sm.right_hand else null
		_:
			var inst: SkillInstance = sm.get_slot(source.trim_prefix("slot_").to_int())
			return inst.data if inst else null

func _cast_source(source: String, context: CastContext = null) -> void:
	if not context:
		context = CastContext.simple(player, player.get_mouse_direction(), _get_skill_for_source(source))
		context.empower = Input.is_key_pressed(KEY_SHIFT)
	if casting._charge_skill and casting._charge_source_matches(source):
		context.charge_power = casting._charge_power
		casting._cancel_charge()
	player.skill_manager.use_source(source, player, context)

func _try_interact() -> void:
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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and event.pressed:
			if casting.aiming_sources.size() > 0:
				casting.cancel_aim = true

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
	return get_viewport().gui_get_hovered_control()!=null

func action_for_source(source: String) -> String:
	if source=="left": return "attack"
	if source=="right": return "skill"
	return "skill_%d"%(int(source.trim_prefix("slot_"))+1)
