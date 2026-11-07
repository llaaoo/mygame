extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []

class CounterEffect extends TriggeredEffect:
	var calls := 0
	func _execute(event: CombatEvent) -> void:
		calls += 1
		if calls == 1:
			_on_event(event) # Reentrancy must already be blocked by the accepted cooldown.

class RecordingExecutor extends SkillExecutor:
	var context: CastContext
	func execute(_skill: SkillData, request: CastContext) -> bool:
		context = request
		return false

class CountingController extends ConditionalCastController:
	var previews := 0
	func preview(skill: SkillData, actor: Node2D, empower: bool = false) -> CastPlan:
		previews += 1
		return super.preview(skill, actor, empower)

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.shift_pressed = pressed
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	var player := game.player
	var sm := player.skill_manager
	var controller := sm.combinations
	var buffs: BuffManager = player.get_node("BuffManager")
	sm.known_actions["pulse"] = true
	controller.learned_rules["echo_pulse"] = true
	controller.learned_rules["guard_pulse"] = true
	sm.equip_slot(0, sm.pool.get_skill("pulse"))
	buffs.apply_buff(load("res://gameplay/abilities/data/resonant_guard_result.tres").buff_resource.duplicate(true))
	buffs.apply_buff(load("res://gameplay/abilities/data/echo_mark_data.tres").buff_resource.duplicate(true))
	player.mana_component.mp = 8
	_shift(true)
	var ordinary := Action.cast("slot_0", Vector2.RIGHT, player)
	_check(not ActionResolver.validate(player, ordinary), "Explicit ordinary request sampled Shift from global input")
	Input.action_press("skill_1")
	Input.action_release("skill_1")
	var actions: Array[Action] = []
	player._poll_universal_cast(actions, "slot_0", "skill_1")
	_check(actions.size() == 1 and actions[0].params.release and actions[0].cast_context.empower, "Input adapter did not capture a strengthened release")
	_shift(false)
	if not actions.is_empty():
		_check(ActionResolver.validate(player, actions[0]), "Affordable 8 MP guard release was rejected as 14 MP echo")
		player.aiming_sources["slot_0"] = true
		player.resolve_action(actions[0])
		_check(not controller.pending.is_empty() and controller.pending.empower and controller.pending.cost == 8, "Execution did not use the validated input snapshot")
		await create_timer(0.5).timeout
		_check(player.mana_component.mp == 0 and not buffs.has_buff("resonant_guard") and buffs.has_buff("echo_ready"), "Guard release spent the wrong cost/status")
	controller.reset_session()
	buffs.clear_all()
	buffs.apply_buff(load("res://gameplay/abilities/data/ember_focus_result.tres").buff_resource.duplicate(true))
	player.mana_component.mp = 4
	var ignite := sm.pool.get_skill("ignite")
	var context := CastContext.simple(player, Vector2.RIGHT, ignite)
	_shift(true)
	_check(sm.use_source("right", player, context) and controller.pending.cost == 4 and not controller.pending.empower, "Explicit false intent was overwritten by live Shift")
	controller.cancel()
	controller.reset_session()
	context.empower = true
	_check(not sm.use_source("right", player, context) and buffs.has_buff("ember_focus"), "Unaffordable empowerment spent its boon")
	_shift(false)
	buffs.clear_all()
	player.mana_component.max_mp = 300
	player.mana_component.mp = 100
	var item := EquipmentData.new()
	item.slot_type = EquipmentData.SlotType.AMULET
	item.combat_modifiers = {"cooldown.all": -0.5}
	var equipment: EquipmentManager = player.get_node("EquipmentManager")
	equipment.equip(item)
	var pulse := sm.pool.get_skill("pulse")
	_check(is_equal_approx(controller.preview(pulse, player).cooldown, sm._get_effective_cooldown(pulse, player)), "Combo cooldown skipped common policy")
	var field := FireSigil.new()
	field.caster = player
	field.position = player.position
	game.region_root.add_child(field)
	controller.fields.append(field)
	controller.learned_rules["fire_sigil_fireball"] = true
	var plan := controller.preview(ignite, player)
	var duration: float = plan.cooldown
	_check(sm.use_source("right", player, CastContext.simple(player, Vector2.RIGHT, ignite)), "Cooldown test failed to start")
	controller._commit()
	equipment.unequip(EquipmentData.SlotType.AMULET)
	_check(is_equal_approx(sm.get_cooldown_total("right"), duration), "Active cooldown duration changed with equipment")
	controller.clear_field()
	var state := sm.get_cooldown_state("right")
	_check(state.remaining <= state.duration, "Leaving a sigil produced an invalid cooldown mask")
	controller.reset_session()

	# Ordinary execution shares one implementation, preserves targeting/charge, refunds once.
	sm.restrict_actions = false
	sm.equip_slot(1, sm.pool.get_skill("shadow_bolt"))
	var original_executor := sm.executor
	var recorder := RecordingExecutor.new()
	sm.add_child(recorder)
	sm.executor = recorder
	context = CastContext.at_position(player, player.position + Vector2.RIGHT * 100, sm.get_slot(1).data)
	context.world = game.region_root
	context.charge_power = 0.35
	var mana := player.mana_component.mp
	_check(not sm.use_source("slot_1", player, context), "Rejecting ordinary executor was accepted")
	_check(recorder.context == context and context.world == game.region_root and context.charge_power == 0.35 and player.mana_component.mp == mana, "Unified execution lost context or failed its mana refund")
	sm.executor = original_executor
	recorder.queue_free()

	var fire := CombatEvent.create(CombatEvent.Type.ON_HIT, player, null)
	fire.skill = sm.pool.get_skill("fireball")
	var ice := CombatEvent.create(CombatEvent.Type.ON_HIT, player, null)
	ice.skill = load("res://gameplay/abilities/data/frost_bolt_result.tres")
	var condition := SkillTagCondition.new()
	condition.required_skill_tag = "fire"
	var effect := CounterEffect.new()
	effect.conditions = [condition]
	effect.cooldown = 10
	effect._on_event(ice)
	effect._on_event(fire)
	_check(effect.calls == 1, "Nonmatching event consumed cooldown or nested event reentered")
	CombatExecutor.instance.tick(10)
	effect._on_event(fire)
	_check(effect.calls == 2, "Simulated cooldown did not expire")
	var graph_calls := [0]
	var graph_effect := TriggeredEffect.new()
	graph_effect.cooldown = 10
	graph_effect.graph = EffectGraph.from_flat([condition], CallableNode.from_callable(func(_ctx): graph_calls[0] += 1))
	graph_effect._on_event(ice)
	graph_effect._on_event(fire)
	graph_effect._on_event(fire)
	_check(graph_calls[0] == 1, "Graph gates did not precede its single cooldown claim")
	var pause_effect := TriggeredEffect.new()
	_check(CombatExecutor.instance.claim_trigger_cooldown(pause_effect, 0.03), "Pause setup failed")
	paused = true
	await create_timer(0.08).timeout
	_check(not CombatExecutor.instance.can_trigger(pause_effect), "Paused real time advanced a game cooldown")
	paused = false
	await create_timer(0.08).timeout
	_check(CombatExecutor.instance.can_trigger(pause_effect), "Resumed simulation did not advance cooldown")
	var bus := CombatEventBus.new()
	var once_calls := [0]
	bus.once(CombatEvent.Type.ON_HEAL, func(event):
		once_calls[0] += 1
		bus.emit(event))
	bus.emit(CombatEvent.create(CombatEvent.Type.ON_HEAL, null, null))
	bus.emit(CombatEvent.create(CombatEvent.Type.ON_HEAL, null, null))
	_check(once_calls[0] == 1 and bus.get_listener_count() == 0, "One-shot subscription repeated under nested emission")

	var detached_calls := [0]
	var detached := func(_event: CombatEvent) -> void:
		detached_calls[0] += 1
	bus.subscribe(CombatEvent.Type.ON_HEAL, func(_event: CombatEvent) -> void:
		bus.unsubscribe(CombatEvent.Type.ON_HEAL, detached))
	bus.subscribe(CombatEvent.Type.ON_HEAL, detached)
	bus.emit(CombatEvent.create(CombatEvent.Type.ON_HEAL, null, null))
	_check(detached_calls[0] == 0, "A removed subscriber still ran later in the same dispatch")

	bus.clear_all()
	bus.subscribe(CombatEvent.Type.ON_HEAL, func(_event: CombatEvent) -> void: bus.clear_all())
	bus.subscribe(CombatEvent.Type.ON_HEAL, detached)
	bus.emit(CombatEvent.create(CombatEvent.Type.ON_HEAL, null, null))
	_check(detached_calls[0] == 0 and bus.get_listener_count() == 0, "Clearing a bus did not cancel the remaining dispatch")

	var bound_effect := TriggeredEffect.new()
	bound_effect.trigger_type = CombatEvent.Type.ON_HEAL
	bound_effect.register(bus)
	bound_effect.trigger_type = CombatEvent.Type.ON_KILL
	bound_effect.unregister()
	_check(bus.get_listener_count() == 0, "Effect unregistered from the wrong bus or event")
	bus.free()

	var counted := CountingController.new()
	counted.setup(sm, player)
	sm.add_child(counted)
	sm.combinations = counted
	controller.queue_free()
	for i in range(SkillManager.MAX_SLOTS):
		sm.equip_slot(i, ignite)
	sm.unequip_hand("left")
	sm.equip_hand("right", ignite)
	var bar := SkillBar.new()
	game.add_child(bar)
	bar.setup(sm)
	counted.previews = 0
	bar._process(0.016)
	_check(counted.previews == 2, "SkillBar did not reuse one plan per ordinary/Shift mode within a refresh")
	buffs.apply_buff(load("res://gameplay/abilities/data/ember_focus_result.tres").buff_resource.duplicate(true))
	bar._process(0.016)
	_check(counted.previews == 4 and bar._panels[1].tooltip_text.contains("余烬战意"), "Next-frame boon changes reused a stale preview")
	bar._process(0.016)
	_check(counted.previews == 4, "Unchanged previews ignored the bounded refresh interval")
	bar.queue_free()
	await fixture.close()
	if failures.is_empty():
		print("Cast refactor passed: real input snapshot, guard cost, explicit intent, shared cooldown, stable duration, context/refund, flat/graph triggers, pause, once and preview reuse")
	quit(0 if failures.is_empty() else 1)
