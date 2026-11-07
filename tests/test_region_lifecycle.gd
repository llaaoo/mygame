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
	var unrelated := Probe.new()
	root.add_child(unrelated)
	RuntimeRegistration.register_ticker(unrelated)
	_check(sim.entity_ticker_count() == baseline, "A node from outside the scene joined the active simulation")
	_check(RuntimeRegistration.combat_bus_for(unrelated) == null, "An unrelated scene could subscribe to the active combat world")
	unrelated.queue_free()
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
	CombatExecutor.report_heal(player, 1)
	var heal_number: DamageNumber
	for child in old_root.get_children():
		if child is DamageNumber:
			heal_number = child
			break
	_check(is_instance_valid(heal_number), "Combat feedback was not placed in the target's region")
	var old_generation := session.generation
	var stale := RuntimeCommand.create(RuntimeCommand.TYPE_SURFACE_CHANGE, "test", RuntimeCommand.Target.SIMULATION, {"surface_state": "burning", "surface_radius": 128})
	stale.scope_id = bus.scope_id
	bus.emit(RuntimeCommand.create(RuntimeCommand.TYPE_DESTROYED, "test", RuntimeCommand.Target.WORLD, {"object_id": "test.queued_fact", "state_data": {"state": "DESTROYED"}, "position": player.global_position, "destruction_surface": "burning", "destruction_surface_radius": 128, "destruction_radius": 128, "destruction_aoe_damage": 9000}))
	var hp_before := player.health_component.hp
	game._change_region("yard")
	_check(player.health_component.hp == hp_before and not player.health_component.is_dead, "Leaving executed old transient damage")
	var world_states := runtime.get_world_runtime().state_manager
	_check(world_states.get_state("test.queued_fact").get("state") == "DESTROYED", "Leaving lost a queued persistent world fact")
	var view := world_states.get_all_states()
	view["test.queued_fact"]["state"] = "INTACT"
	_check(world_states.get_state("test.queued_fact").get("state") == "DESTROYED", "Editing a world snapshot rewrote the active world")
	_check(sim.surface_cells().is_empty(), "Old commands created surfaces in the new region")
	bus.emit(stale)
	bus.dispatch()
	_check(sim.surface_cells().is_empty(), "Stale scoped command affected the new region")
	_check(not old_root.is_inside_tree() and old_root.is_queued_for_deletion() and not session.is_current(old_generation), "Old region remained active")
	_check(not buffs.has_buff("ember_focus") and is_equal_approx(player.move_speed, equipped_speed) and equipment.get_equipment(EquipmentData.SlotType.FEET) == boots, "Region cleanup lost persistent equipment or kept temporary statuses")
	_check("region_cleanup" in removal_reasons and "expired" not in removal_reasons, "Region cleanup impersonated natural expiry")
	_check(player.casting._charging_source.is_empty() and player.casting._channeling_source.is_empty() and player.casting.aiming_sources.is_empty() and sm.combinations.pending.is_empty(), "Region change retained a cast/aim session")
	await _frames()
	_check(not is_instance_valid(heal_number), "Combat feedback survived its region")
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
	await _check_standalone_scene()
	await _check_legacy_travel()
	if failures.is_empty():
		print("Region lifecycle passed: readiness, scoped commands/facts/effects, stale callbacks, repeated travel, legacy portal and persistent attributes")
	quit(0 if failures.is_empty() else 1)


func _check_standalone_scene() -> void:
	var detached := GameRuntime.new()
	_check(GameRuntime.instance == null, "Instantiating a detached scene installed its runtime")
	detached.free()
	var pending_before := RuntimeRegistration._waiting.size()
	var standalone := Node2D.new()
	var npc := DialogueNPC.new()
	npc.enable_schedule = false
	standalone.add_child(npc)
	standalone.add_child(MapObject.new())
	standalone.add_child(WorldTime.new())
	root.add_child(standalone)
	# A self-deferred registration without a runtime used to prevent this frame from arriving.
	await _frames(2)
	standalone.queue_free()
	await _frames(2)
	_check(WorldTime.instance == null, "Standalone clock kept its global reference after removal")
	_check(RuntimeRegistration._waiting.size() == pending_before, "Unloaded standalone nodes left pending ticker registrations")


func _check_legacy_travel() -> void:
	const OVERWORLD := "res://world/maps/overworld.tscn"
	const FOREST := "res://world/regions/burning_forest/burning_forest.tscn"
	var packed := load("res://main.tscn") as PackedScene
	var game := packed.instantiate()
	var run := game.get_node("RunManager") as RunManager
	run.enabled = false
	root.add_child(game)
	current_scene = game
	await _frames()

	var runtime := game.get_node("GameRuntime") as GameRuntime
	var regions := runtime.get_region_runtime()
	var session := runtime.get_region_session()
	var player := game.get_node("Player") as Player
	var original := game.get_node("Overworld") as Node2D
	var generation := session.generation
	var portal := original.get_node("PrisonGameplay/ExitGate") as Portal
	var old_position := player.global_position

	var wrong_root := await regions.ensure_region("res://ui/hud.tscn")
	var missing_marker := await regions.ensure_region(FOREST, "unknown_marker")
	_check(not wrong_root and not missing_marker, "Malformed destinations were accepted")
	_check(regions.get_current_region() == original and session.is_current(generation), "Rejected travel unloaded the source map")
	_check(player.global_position.is_equal_approx(old_position), "Rejected travel moved the player")

	portal.unlock()
	player.global_position = portal.global_position
	await _wait_for_region(regions, FOREST)
	var forest := regions.get_current_region()
	_check(regions.get_current_region_path() == FOREST, "Physics overlap did not enter the forest")
	_check(not is_instance_valid(original) or not original.is_inside_tree(), "Portal left the old region in the tree")
	if is_instance_valid(forest) and forest.scene_file_path == FOREST:
		var entry := MarkerRegistry.find_marker("burning_forest_entry", forest)
		_check(entry != null and player.global_position.is_equal_approx(entry.global_position), "Portal ignored the destination marker")
		_check(WorldScope.resolve(player) == forest, "Player effects still resolve to the previous map")
		var saves := runtime.get_node("SaveManager") as SaveManager
		var saved_position := player.global_position
		_check(saves.save_game(31), "Could not save from the forest")

		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = true
		Input.parse_input_event(escape)
		Input.flush_buffered_events()
		await _wait_for_region(regions, OVERWORLD)
		escape.pressed = false
		Input.parse_input_event(escape)
		Input.flush_buffered_events()
		var returned := regions.get_current_region()
		var return_marker := MarkerRegistry.find_marker("overworld_from_forest", returned)
		_check(regions.get_current_region_path() == OVERWORLD, "Escape did not return to Overworld")
		_check(return_marker != null and player.global_position.is_equal_approx(return_marker.global_position), "Return used the wrong map marker")
		var rejected_position := player.global_position
		var rejected_hour := WorldTime.instance.get_hour()
		var wrong_save: Dictionary = saves.read_slot(31).data.duplicate(true)
		wrong_save.meta.region_id = "res://ui/hud.tscn"
		wrong_save.world.world_time_hour = 23.0
		_check(saves.repository.write("user://save_32.sav", wrong_save), "Could not write invalid-destination test save")
		await saves.load_game(32)
		_check(saves.active_slot == 31 and regions.get_current_region() == returned, "Rejected save changed the slot or region")
		_check(player.global_position.is_equal_approx(rejected_position) and absf(WorldTime.instance.get_hour() - rejected_hour) < 0.5, "Rejected save changed player or world state")

		await saves.load_game(31)
		_check(regions.get_current_region_path() == FOREST and player.global_position.is_equal_approx(saved_position), "Valid legacy save did not restore its map and position")

	game.queue_free()
	current_scene = null
	await _frames()


func _wait_for_region(regions: RegionRuntime, path: String) -> void:
	for i in range(12):
		await physics_frame
		await process_frame
		if regions.get_current_region_path() == path:
			break
