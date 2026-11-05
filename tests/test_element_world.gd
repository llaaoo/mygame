extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func _frames() -> void:
	for i in range(4): await process_frame
func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	game._change_region("cistern")
	for enemy in game.active_enemies: enemy.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.global_position = Vector2(-350, 260)
	var valve: SurfaceValve
	var receiver: SpellWorldObject
	for child in game.region_root.get_children():
		if child is SurfaceValve: valve = child
		if child is SpellWorldObject and child.spec.id == "magic.waterworks_conductor": receiver = child
	check(valve != null and receiver != null, "Authored cistern valve/conductor were not mounted")
	if not valve or not receiver:
		await fixture.close()
		quit(1)
		return
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	var first := SurfaceManager.cell_at(valve.spec.paths[0].points[0])
	var middle := SurfaceManager.cell_at(Vector2(32, 96))
	var end := SurfaceManager.cell_at(receiver.global_position)
	var skill := SkillData.new()
	skill.tags = ["lightning"]
	CombatExecutor.report_hit(game.player, receiver, 0, receiver.global_position, skill, skill.tags)
	receiver.tick(.6)
	check(not receiver.completed and surfaces.get_surface(end).state == "dry", "A direct lightning tag powered a dry surface-only mechanism")
	valve.cycle(game.player)
	check(valve.mode == "a" and game.progress.choices.get(valve.spec.id) == "a" and surfaces.get_surface(end).state == "wet", "Valve did not create/persist its authored water route")
	surfaces.apply_tags(middle, ["ice"])
	surfaces.apply_tags(first, ["lightning"])
	receiver.tick(.6)
	check(surfaces.get_surface(end).state == "wet" and not receiver.completed, "Conduction crossed the frozen break")
	valve.tick(1)
	check(surfaces.get_surface(middle).state == "frozen" and surfaces.get_surface(first).state == "electrified", "Refilling erased a prepared ice/electric reaction")
	surfaces.apply_tags(middle, ["impact"])
	surfaces.apply_tags(middle, ["lightning"])
	check(surfaces.get_surface(end).state == "electrified", "Shattering did not reconnect the real route")
	receiver.tick(.25)
	check(not receiver.completed, "Surface hold completed before 0.5 seconds")
	surfaces.force_set_surface(end, "wet", 12)
	receiver.tick(.1)
	surfaces.apply_tags(end, ["lightning"])
	receiver.tick(.25)
	check(not receiver.completed, "Broken surface condition retained hold progress")
	var supplies := game.player.skill_manager.combinations.supplies
	var crystal := supplies.count("crystal")
	receiver.tick(.25)
	check(receiver.completed and game.progress.claims.has(receiver.spec.id) and supplies.count("crystal") == crystal + 3, "Actual held environment condition failed to persist/reward")
	receiver.tick(10)
	check(supplies.count("crystal") == crystal + 3, "Latched mechanism repeated its reward")
	valve.cycle()
	check(valve.mode == "b" and surfaces.get_surface(first).state == "electrified", "Rerouting cleared the old transformed water")
	valve.cycle()
	check(valve.mode == "off" and surfaces.get_surface(end).state == "electrified", "Closing instantly removed residual water")
	valve.cycle()
	valve.cycle()
	check(game.progress.choices.get(valve.spec.id) == "b", "Final valve mode not recorded")
	# New caches are one-time, including across region reconstruction and disk restore.
	var cache: ExplorationDiscoveryData
	for note in game.current_data.discoveries:
		if note.id == "experiment.cistern_trial_supply": cache = note
	check(game.progress_service.discover(cache), "Trial supply could not be claimed")
	crystal = supplies.count("crystal")
	check(not game.progress_service.discover(cache) and supplies.count("crystal") == crystal, "Repeated trial supply duplicated stock")
	game._change_region("archive")
	for enemy in game.active_enemies: enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var fence: MapObject
	for child in game.region_root.get_children():
		if child is MapObject and child.persistent_id == "experiment.archive_fence": fence = child
	check(fence != null, "Authored flammable fence missing")
	if fence:
		CombatExecutor.report_hit(game.player, fence, 30, fence.global_position, null, ["melee"])
		await _frames()
		check(fence.get_state().state == "DESTROYED", "Ordinary melee could not clear the alternative fence route")
	var bus := GameRuntime.instance.get_command_bus()
	bus.emit(RuntimeCommand.create(RuntimeCommand.TYPE_DESTROYED, "save-test", RuntimeCommand.Target.WORLD, {"object_id": "test.save_fact", "state_data": {"state": "DESTROYED"}, "position": game.player.global_position, "destruction_surface": "burning", "destruction_surface_radius": 128, "destruction_radius": 128, "destruction_aoe_damage": 9000}))
	var hp := game.player.health_component.hp
	var scope_id := bus.scope_id
	check(SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Element world save failed")
	check(game.player.health_component.hp == hp and not game.player.health_component.is_dead and bus.scope_id == scope_id, "Saving executed pending transient damage or changed the active scope")
	check(GameRuntime.instance.get_world_runtime().state_manager.get_state("test.save_fact").get("state") == "DESTROYED" and not bus._queue.is_empty(), "Saving dropped persistent facts or discarded retained transient work")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	game._change_region("cistern")
	for child in game.region_root.get_children():
		if child is SurfaceValve: check(child.mode == "b", "Fresh disk restore lost valve mode")
		if child is SpellWorldObject and child.spec.id == "magic.waterworks_conductor": check(child.completed, "Fresh disk restore lost latched mechanism")
	check(game.player.skill_manager.combinations.supplies.count("crystal") == crystal, "Restoration regenerated the mechanism/cache reward")
	game._change_region("archive")
	for child in game.region_root.get_children():
		if child is MapObject and child.persistent_id == "experiment.archive_fence":
			check(child.get_state().state == "DESTROYED", "Fence destruction did not persist")
			await _frames()
			check((child.get_node("Body/CollisionShape2D") as CollisionShape2D).disabled, "Restored destroyed fence left an invisible collision obstacle")
	var chapter := game.catalog.chapter.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ExplorationChapterData
	for region in chapter.regions:
		if region.id == "cistern": region.spell_objects[0].routes[0].required_surface = "unknown_surface"
	check("Invalid surface puzzle condition" in "\n".join(ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(chapter))), "Validator accepted an unknown world condition")
	await fixture.close()
	if errors.is_empty(): print("Element world passed: real circuit, ice break, hold reset, bounded refill, rerouting, optional supplies and persistent fence/valve/reward")
	quit(0 if errors.is_empty() else 1)
