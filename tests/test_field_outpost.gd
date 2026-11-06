extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
const BUILT := "outpost.drain_built"
var errors: Array[String] = []
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func facility(game: MVPGame) -> ExplorationInteractable:
	for node in game.region_root.get_children():
		if node.has_meta("repair_facility"): return node
	return null
func pot(game: MVPGame) -> ExplorationInteractable:
	for node in game.region_root.get_children():
		if node.has_meta("survival_station") and node.get_meta("survival_station").id == "survival.station.drain_pot": return node
	return null
func _run() -> void:
	var fixture := Fixture.new(self)
	var game := await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	game._change_region("drain")
	for enemy in game.active_enemies:
		enemy.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
	var node := facility(game)
	var spec: RepairFacilityData = node.get_meta("repair_facility")
	var player := game.player
	var work := player.field_work
	var supplies := player.skill_manager.combinations.supplies
	player.position = node.position
	check(pot(game) == null and not game.progress.claims.has(BUILT), "Unbuilt outpost supplied services")
	game.alchemy.inspect(node, spec)
	check(not work.start_selected(), "Construction ignored uncleared region")
	game.progress.cleared.drain = true
	check(not work.start_selected(), "Construction ignored live replay enemies")
	for enemy in game.active_enemies: enemy.queue_free()
	game.active_enemies.clear()
	for i in range(3): await process_frame
	supplies.amounts.grain = 0
	check(not work.start_selected(), "Construction ignored missing supplies")
	supplies.grant({"charcoal": 2, "grain": 2})
	var before := supplies.serialize()
	check(work.start_selected(), "Valid construction could not start")
	work.tick(2.99)
	check(not game.progress.claims.has(BUILT) and supplies.serialize() == before, "Construction paid early")
	player.take_damage(1)
	check(not work.is_busy() and supplies.serialize() == before, "Interrupted construction leaked materials")
	check(work.start_selected(), "Construction retry failed")
	work.tick(3)
	check(game.progress.claims.has(BUILT) and supplies.count("grain") == int(before.amounts.grain) - 2 and supplies.count("charcoal") == int(before.amounts.charcoal) - 2, "Construction failed exact payment")
	check(not game.progress.claims.has(AlchemyRepairService.PUMP) and pot(game) != null, "Outpost granted pump or failed instant services")
	before = supplies.serialize()
	check(not game.alchemy._assemble(spec.assembly, node, spec) and supplies.serialize() == before, "Repeated build charged again")
	player.health_component.hp = 30
	player.mana_component.mp = 10
	game.survival.needs.nutrition = 80
	game.survival.needs.hydration = 80
	game.survival.needs.fatigue = 50
	game.alchemy.inspect(node, spec)
	check(work.methods.size() == 1 and work.methods[0].id == "rest:short", "Outpost exposed full rest or coarse food")
	check(work.start_selected(), "Outpost short rest failed")
	work.tick(3)
	check(player.health_component.hp == 70 and player.mana_component.mp == 40 and game.survival.needs.fatigue == 25 and game.survival.needs.nutrition == 75 and game.survival.needs.hydration == 70, "Field short rest changed authored costs/recovery")
	var cooker := pot(game)
	var station: SurvivalStationData = cooker.get_meta("survival_station")
	check(not game.survival.has_heat(cooker, station) and game.survival.cooking_cost("ration", cooker, station).get("charcoal", 0) == 1, "Outpost auto-lit or provided free fuel")
	SurfaceManager.instance.apply_area(cooker.global_position + station.heat_offset, 0, ["fire"], "player spark")
	check(game.survival.has_heat(cooker, station) and not game.survival.cooking_cost("ration", cooker, station).has("charcoal"), "Actual player-created fire did not supply cooking heat")
	game.builder.mount_available_stations()
	var count := 0
	for child in game.region_root.get_children():
		if child.has_meta("survival_station") and child.get_meta("survival_station") == station: count += 1
	check(count == 1, "Repeated facility refresh duplicated cook site")
	game._save_progress()
	game._change_region("camp")
	game._change_region("drain")
	node = facility(game)
	check(game.progress.claims.has(BUILT) and pot(game) != null and game.active_enemies.is_empty(), "Travel lost outpost or respawned cleared encounter")
	game.player.position = node.position
	game.alchemy.inspect(node, game.current_data.facilities[0])
	check(work.start_selected(), "Saved outpost cannot short rest")
	game.player.take_damage(1)
	check(not work.is_busy() and game.progress.claims.has(BUILT), "Replay damage did not interrupt field rest or revoked permanent facility")
	await fixture.close()
	game = await fixture.boot(true)
	game._change_region("drain")
	check(game.progress.claims.has(BUILT) and pot(game) != null, "Disk reload lost completed facility")
	await fixture.close()
	if errors.is_empty(): print("Field outpost passed: clear/live enemy gates, delayed atomic payment, interruption, once-only build, short rest, real heat, station deduplication and persistence")
	quit(0 if errors.is_empty() else 1)
