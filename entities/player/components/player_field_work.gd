class_name PlayerFieldWork
extends Node
signal feedback_requested(message: String)
signal work_committed(method: FieldWorkMethod)
signal work_started(method: FieldWorkMethod)
signal work_cancelled(method: FieldWorkMethod, reason: String)
const RANGE := 80.0
var player: Player
var panel: FieldWorkPanel
var target: Node2D
var methods: Array[FieldWorkMethod] = []
var selected := 0
var pending: Dictionary = {}
var _reason_provider: Callable
var _commit_provider: Callable
var _title := ""
var _guide := ""
var _scope: Node
var _generation := 0
var _last_hp := 0
var _refresh := 0.0
var _committing := false

func _init(actor: Player) -> void: player = actor
func _ready() -> void:
	set_process(false)
	RuntimeRegistration.register_ticker(self)
	panel = FieldWorkPanel.new()
	add_child(panel)
	panel.selector.item_selected.connect(func(index: int):
		if not is_busy(): selected=index; _refresh_panel())
	panel.start_button.pressed.connect(start_selected)
	panel.cancel_button.pressed.connect(func(): cancel("已取消作业"); close_panel())
	_last_hp = player.health_component.hp
	player.health_component.health_changed.connect(_on_health)

func is_busy() -> bool: return not pending.is_empty() or _committing

func inspect(node: Node2D, title: String, options: Array[FieldWorkMethod], reason: Callable, commit: Callable, guide := "") -> void:
	if is_busy() or player.ui_blocked or player.health_component.is_dead: return
	target = node
	_title = title
	methods.assign(options)
	selected = 0
	_reason_provider = reason
	_commit_provider = commit
	_guide = guide
	_scope = CastContext.default_world(player)
	_generation = GameRuntime.instance.get_region_session().generation
	_refresh_panel()

func _input(event: InputEvent) -> void:
	if not panel.visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		cancel("已取消作业")
		close_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("field_method"):
		if not is_busy() and not methods.is_empty():
			selected = (selected + 1) % methods.size()
			_refresh_panel()
		get_viewport().set_input_as_handled()

func interact() -> bool:
	if is_busy():
		cancel("已取消作业")
		return true
	if not panel.visible: return false
	if not _in_range():
		close_panel()
		return false
	if not methods.is_empty(): start_selected()
	return true

func reason_for(method: FieldWorkMethod) -> String:
	if not method or not method.validation_error().is_empty(): return "作业配置无效"
	if not _in_range(): return "靠近设备后再操作（80范围内）"
	if not _reason_provider.is_valid() or not _commit_provider.is_valid(): return "设备已不可用"
	var reason: String = _reason_provider.call(method)
	if not reason.is_empty(): return reason
	if not player.stats_component.meets_requirements(method.required_attributes):
		return player.stats_component.describe_requirements(method.required_attributes)
	if not player.skill_manager.combinations.supplies.can_pay(method.material_costs): return "材料不足"
	return ""

func start_selected() -> bool:
	if is_busy() or methods.is_empty() or player.ui_blocked or get_tree().paused or player.health_component.is_dead: return false
	var method := methods[selected]
	var reason := reason_for(method)
	if not reason.is_empty():
		feedback_requested.emit(reason)
		return false
	if Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > .05:
		feedback_requested.emit("先站定，再开始作业")
		return false
	player.skill_manager.combinations.cancel("现场作业：施法准备取消")
	player.casting.cancel_all()
	_last_hp = player.health_component.hp
	var equipment := player.get_node("EquipmentManager") as EquipmentManager
	pending = {"method": method, "fingerprint": method.fingerprint(), "remaining": method.duration * _efficiency(), "duration": method.duration * _efficiency(), "position": player.global_position, "attributes": player.stats_component.primary_values(), "equipment": equipment.loadout_revision,"progression":player.mastery_manager.revision}
	player.state_machine.transition_to("work")
	work_started.emit(method)
	_refresh_panel()
	return true

func tick(delta: float) -> void:
	if not is_instance_valid(target):
		cancel("设备已离开")
		close_panel()
		return
	if player.health_component.is_dead or player.ui_blocked or not _in_range():
		cancel("操作已中断")
		close_panel()
		return
	if is_busy() and not pending.is_empty():
		var method: FieldWorkMethod = pending.method
		var equipment := player.get_node("EquipmentManager") as EquipmentManager
		if method.fingerprint() != pending.fingerprint or player.stats_component.primary_values() != pending.attributes or equipment.loadout_revision != pending.equipment or player.mastery_manager.revision!=pending.progression:
			cancel("属性、装备或操作条件改变，未扣材料")
		elif player.global_position.distance_to(pending.position) > 12:
			cancel("移动：作业取消")
		elif not reason_for(method).is_empty():
			cancel("操作条件已失效，未扣材料")
		else:
			pending.remaining -= delta
			if pending.remaining <= 0.000001: _commit()
	_refresh -= delta
	if _refresh <= 0:
		_refresh = .1
		_refresh_panel()

func _commit() -> void:
	var method: FieldWorkMethod = pending.method
	_committing = true
	pending = {}
	var accepted: bool = _commit_provider.call(method)
	_committing = false
	_to_idle()
	close_panel()
	if accepted:
		work_committed.emit(method)
		if player.actor_context and not method.id.begins_with("awakening:") and not method.id.begins_with("sleep") and not method.id.begins_with("rest") and not method.id.begins_with("eat") and not method.id.begins_with("basic") and not method.id.begins_with("fill") and not method.id.begins_with("harvest") and not method.id.begins_with("cook"):
			player.actor_context.facts.publish("field_work",player.actor_context.id,{"method":method.id})
	else:
		work_cancelled.emit(method, "操作条件失效")
		feedback_requested.emit("操作条件已失效，未扣材料")

func cancel(reason: String = "作业取消", change_state := true) -> void:
	if pending.is_empty(): return
	var method: FieldWorkMethod = pending.method
	pending = {}
	work_cancelled.emit(method, reason)
	if change_state: _to_idle()
	feedback_requested.emit(reason)

func close_panel() -> void:
	if panel: panel.hide()
	if not is_busy():
		target = null
		methods.clear()
		_reason_provider = Callable()
		_commit_provider = Callable()

func _to_idle() -> void:
	if player.state_machine.current_state.name.to_lower() == "work": player.state_machine.transition_to("idle")

func _in_range() -> bool:
	return is_instance_valid(target) and target.is_inside_tree() and target.global_position.distance_to(player.global_position) <= RANGE and is_instance_valid(_scope) and _scope == CastContext.default_world(player) and GameRuntime.instance.get_region_session().is_current(_generation)

func _on_health(hp: int, _maximum: int) -> void:
	if hp < _last_hp: cancel("受到伤害：作业取消，未扣材料")
	_last_hp = hp

func _refresh_panel() -> void:
	if not _in_range(): return
	var method: FieldWorkMethod=methods[selected] if not methods.is_empty() else null
	var reason:=reason_for(method) if method else ""
	panel.choices(methods,selected,is_busy(),reason)
	var summary:=method.title if method else "当前没有可用作业"
	# The existing sleep operation ID is the same value used by the time service.
	# The display does not invent another duration or advance time itself.
	if method and method.id.begins_with("sleep:"): summary="休息 %s 小时（游戏时间）"%method.id.get_slice(":",1)
	var seconds:=float(pending.remaining) if not pending.is_empty() else method.duration*_efficiency() if method else 0.0
	var cost:=player.skill_manager.combinations.supplies.describe_cost(method.material_costs) if method and not method.material_costs.is_empty() else ""
	var guide:=_guide+"\n"+InputBindings.label("field_method")+"切换作业 · "+InputBindings.label("interact")+"开始 · Esc收起\n移动、其他动作或受伤会中断；成功完成才结算。"
	panel.present_work(_title,summary,seconds,cost,reason,guide,1-float(pending.remaining)/float(pending.duration) if not pending.is_empty() else -1.0)

func _efficiency() -> float:
	if not methods.is_empty() and methods[selected].fixed_duration: return 1.0
	if not methods.is_empty() and (methods[selected].id.begins_with("rest") or methods[selected].id.begins_with("sleep")): return 1.0
	return (player.mastery_manager.activity_efficiency(SkillMastery.School.CRAFTING) if player.mastery_manager else 1.0)*float(ActorProgression.values(player).work_multiplier)
