extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []

class Probe extends Node:
	var calls := 0
	func tick(_delta: float) -> void:
		calls += 1

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _frames(count := 6) -> void:
	for i in range(count):
		await process_frame

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	var runtime := GameRuntime.instance
	var sim := runtime.get_simulation_runtime()
	var session := runtime.get_region_session()
	var bus := runtime.get_command_bus()
	var player := game.player
	var sm := player.skill_manager
	var buffs: BuffManager = player.get_node("BuffManager")
	var baseline := sim.entity_ticker_count()
	_check(sim._entity_tickers.has(sm.combinations.get_instance_id()) and sim._entity_tickers.has(player.casting.get_instance_id()) and sim._entity_tickers.has(player.bindings.get_instance_id()), "Early sibling component registration was lost")
	var probe := Probe.new()
	game.region_root.add_child(probe)
	RuntimeRegistration.register_ticker(probe)
	RuntimeRegistration.register_ticker(probe)
	var calls := probe.calls
	sim._tick_entities(0.01)
	_check(probe.calls == calls + 1 and sim.entity_ticker_count() == baseline + 1, "Ticker registered twice")

	var boots := EquipmentData.new()
	boots.slot_type = EquipmentData.SlotType.FEET
	boots.stat_modifiers = {"move_speed": 15}
	var equipment: EquipmentManager = player.get_node("EquipmentManager")
	equipment.equip(boots)
	var equipped_speed := player.move_speed
	buffs.apply_buff((load("res://gameplay/abilities/data/ember_focus_result.tres") as SkillData).buff_resource)
	var removal_reasons: Array[String] = []
	var removed := func(event: CombatEvent):
		if event.target == player:
			removal_reasons.append(event.data.get("reason", ""))
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_STATUS_REMOVED, removed)
	player.casting._begin_charge("slot_0", sm.pool.get_skill("charged_fireball"))
	player.casting._begin_channel("slot_1", sm.pool.get_skill("ice_storm"))
	player.casting.aiming_sources["slot_0"] = true
	var projectile := sm.pool.get_skill("shadow_bolt")
	var context := CastContext.simple(player, Vector2.RIGHT, projectile)
	_check(context.world == game.region_root, "Default ordinary effects escape their region")
	_check(sm.executor.execute(projectile, context), "Ordinary projectile execution rejected")
	var old_root := game.region_root
	var old_generation := session.generation
	var stale := RuntimeCommand.create(RuntimeCommand.TYPE_SURFACE_CHANGE, "test", RuntimeCommand.Target.SIMULATION, {"surface_state": "burning", "surface_radius": 128})
	stale.scope_id = bus.scope_id
	bus.emit(RuntimeCommand.create(RuntimeCommand.TYPE_DESTROYED, "test", RuntimeCommand.Target.WORLD, {"object_id": "test.queued_fact", "state_data": {"state": "DESTROYED"}, "position": player.global_position, "destruction_surface": "burning", "destruction_surface_radius": 128, "destruction_radius": 128, "destruction_aoe_damage": 9000}))
	var hp_before := player.health_component.hp
	game._change_region("yard")
	_check(player.health_component.hp == hp_before and not player.health_component.is_dead, "Leaving executed old transient damage")
	_check(runtime.get_world_runtime().state_manager.get_state("test.queued_fact").get("state") == "DESTROYED", "Leaving lost a queued persistent world fact")
	_check(sim.surface_cells().is_empty(), "Old commands created surfaces in the new region")
	bus.emit(stale)
	bus.dispatch()
	_check(sim.surface_cells().is_empty(), "Stale scoped command affected the new region")
	_check(not old_root.is_inside_tree() and old_root.is_queued_for_deletion() and not session.is_current(old_generation), "Old region remained active")
	_check(not buffs.has_buff("ember_focus") and is_equal_approx(player.move_speed, equipped_speed) and equipment.get_equipment(EquipmentData.SlotType.FEET) == boots, "Region cleanup lost persistent equipment or kept temporary statuses")
	_check("region_cleanup" in removal_reasons and "expired" not in removal_reasons, "Region cleanup impersonated natural expiry")
	_check(player.casting._charging_source.is_empty() and player.casting._channeling_source.is_empty() and player.casting.aiming_sources.is_empty() and sm.combinations.pending.is_empty(), "Region change retained a cast/aim session")
	await _frames()
	var enemy_count := game.active_enemies.size()
	game._on_enemy_died(null, old_generation)
	_check(game.active_enemies.size() == enemy_count and not game.progress.cleared.has("yard"), "Old enemy callback changed the new encounter")
	game.request_travel("camp")
	await _frames()
	_check(sim.entity_ticker_count() == baseline, "Ticker list retained unloaded region entities")
	for i in range(3):
		game.request_travel("yard")
		await _frames()
		game.request_travel("camp")
		await _frames()
		_check(sim.entity_ticker_count() == baseline, "Repeated travel accumulated ticker registrations")
	CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_STATUS_REMOVED, removed)
	await fixture.close()
	_check(not is_instance_valid(sim) and GameRuntime.instance == null, "Scene shutdown retained its runtime")
	if failures.is_empty():
		print("Region lifecycle passed: readiness, scoped commands/facts/effects, stale callbacks, repeated travel and persistent attributes")
	quit(0 if failures.is_empty() else 1)
