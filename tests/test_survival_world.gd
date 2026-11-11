extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var game: MVPGame
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func frames() -> void:
	for i in range(5): await process_frame
func travel(id: String) -> void:
	game.ui.close_modal()
	game._change_region(id)
	for enemy in game.active_enemies:
		enemy.set_physics_process(false)
		enemy.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
	await frames()
func station(id: String) -> ExplorationInteractable:
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.has_meta("survival_station"):
			var spec: SurvivalStationData = node.get_meta("survival_station", null)
			if spec and spec.id.ends_with(id): return node
	return null
func operate(node: ExplorationInteractable, id: String) -> bool:
	game.player.position = node.position
	node.callback.call()
	var work := game.player.field_work
	for i in range(work.methods.size()):
		if work.methods[i].id == id: work.selected = i
	if work.methods.is_empty() or work.methods[work.selected].id != id or not work.start_selected(): return false
	work.tick(work.pending.duration)
	return not work.is_busy()
func run() -> void:
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(false)
	var survival := game.survival
	var supplies := survival.supplies
	var work := game.player.field_work
	for note in game.current_data.discoveries:
		if note.id == "survival.pack":
			check(game.progress_service.discover(note), "Starter provisions missing")
			var stock := supplies.serialize()
			check(not game.progress_service.discover(note) and supplies.serialize() == stock, "Starter provisions duplicated")
	check(SurvivalCatalog.water_count(supplies) == 4, "Starter waterskin not bounded")
	survival.needs.hydration = 30
	var stock := supplies.serialize()
	survival.begin_eating("clean_water")
	check(work.is_busy() and not paused and not game.player.ui_blocked, "Eating/drinking paused or bypassed live work")
	game.player.health_component.invincible = false
	CombatExecutor.report_hit(null, game.player, 1, game.player.position, null, ["test"])
	check(not work.is_busy() and supplies.serialize() == stock and survival.needs.hydration == 30, "Damage interruption consumed drink/effect")
	survival.begin_eating("clean_water")
	work.tick(1)
	check(supplies.count("clean_water") == 3 and survival.needs.hydration == 70 and survival.needs.water_remaining == 120, "Successful drinking payment/effect failed")
	var stove := station("camp_stove")
	var grain := supplies.count("grain")
	check(operate(stove, "cook:ration") and supplies.count("grain") == grain - 1 and supplies.count("ration") == 3 and supplies.count("charcoal") == 0, "Camp stove recipe charged fuel or produced wrong output")
	await travel("archive")
	var pot := station("archive_pot")
	game.player.position = pot.position
	pot.callback.call()
	check(not work.start_selected(), "Cold field pot cooked without fuel or actual fire")
	supplies.grant({"charcoal": 3})
	var spec: SurvivalStationData = pot.get_meta("survival_station")
	var cold := survival.cooking_cost("ration", pot, spec)
	check(cold == {"grain": 1, "charcoal": 1}, "Field fuel preview incorrect")
	# Real fire action reacts with the authored kindling; no synthetic fire flag.
	game.player.skill_manager.restrict_actions = false
	game.player.position = pot.position + spec.heat_offset - Vector2(34, 34)
	var sm := game.player.skill_manager
	sm.equip_slot(0, sm.pool.get_skill("ignite"))
	check(sm.use_source("slot_0", game.player, CastContext.simple(game.player, Vector2.ONE.normalized(), sm.pool.get_skill("ignite"))), "Fire action rejected at kindling")
	sm.combinations.tick(.6)
	await create_timer(.25).timeout
	GameRuntime.instance.get_simulation_runtime()._propagation_scheduler.tick(.1)
	check(SurfaceManager.instance.surface_at(game.player.position).get("state", "dry") == "dry", "Field cooking has no safe position within interaction range")
	check(survival.has_heat(pot, spec) and survival.cooking_cost("ration", pot, spec) == {"grain": 1}, "Actual fire did not substitute cooking fuel")
	game.player.position = pot.position
	pot.callback.call()
	stock = supplies.serialize()
	check(work.start_selected(), "Borrowed heat cooking could not start")
	SurfaceManager.instance.apply_area(pot.position + spec.heat_offset, 0, ["water"], "test quench")
	work.tick(.1)
	check(not work.is_busy() and supplies.serialize() == stock, "Extinguished heat silently charged charcoal or ingredients")
	for note in game.current_data.discoveries:
		if note.id == "survival.archive_recipe": check(game.progress_service.discover(note), "Tea knowledge unavailable")
	var forage := station("archive_grain")
	grain = supplies.count("grain")
	check(operate(forage, "harvest") and supplies.count("grain") == grain + 2, "Forage did not grant authored provisions")
	forage.callback.call()
	check(not work.start_selected(), "Forage immediately repeated")
	await travel("camp")
	await travel("archive")
	forage = station("archive_grain")
	game.player.position = forage.position
	forage.callback.call()
	check(not work.start_selected(), "Reentering region reset forage cooldown")
	survival.needs.tick(240, 10)
	check(operate(forage, "harvest"), "Forage did not regenerate on simulation time")
	await travel("drain")
	var source := station("drain_water")
	var water_spec: SurvivalStationData = source.get_meta("survival_station")
	check(survival.water_quality(source, water_spec) == "dirty_water", "Unrepaired drain source was potable")
	var cell := SurfaceManager.cell_at(source.position)
	SurfaceManager.instance.force_set_surface(cell, "frozen", 5)
	check(survival.water_quality(source, water_spec) == "blocked", "Frozen source remained drawable")
	SurfaceManager.instance.apply_tags(cell, ["fire"], "test melt")
	check(survival.water_quality(source, water_spec) == "dirty_water", "Melting purified the source")
	game.progress.claims[AlchemyRepairService.PUMP] = true
	check(survival.water_quality(source, water_spec) == "clean_water", "Repair did not improve source quality")
	SurfaceManager.instance.apply_tags(cell, ["lightning"], "test conduction")
	check(survival.water_quality(source, water_spec) == "blocked", "Electrified source remained drawable")
	SurfaceManager.instance.force_set_surface(cell, "poisoned", 5)
	check(survival.water_quality(source, water_spec) == "dirty_water", "Contamination ignored after permanent repair")
	SurfaceManager.instance.force_set_surface(cell, "wet", 10)
	supplies.pay({"clean_water": supplies.count("clean_water"), "dirty_water": supplies.count("dirty_water")})
	check(operate(source, "fill:clean_water:4") and supplies.count("clean_water") == 4, "Repaired source could not fill waterskin")
	await travel("camp")
	stove = station("camp_stove")
	supplies.pay({"clean_water": supplies.count("clean_water")})
	supplies.grant({"dirty_water": 4})
	check(operate(stove, "cook:purify") and supplies.count("clean_water") == 1 and supplies.count("dirty_water") == 3 and SurvivalCatalog.water_count(supplies) == 4, "Purification lost capacity or double-charged fuel")
	check(operate(stove, "cook:tea") and supplies.count("tea") == 1, "Learned tea recipe failed")
	survival.needs.fatigue = 80
	(game.player.get_node("BuffManager") as BuffManager).apply_buff(load("res://gameplay/abilities/data/poison.tres"), game.player)
	survival.begin_eating("tea")
	(game.player.get_node("BuffManager") as BuffManager).tick(.25)
	work.tick(.5)
	check(survival.needs.fatigue == 65 and not (game.player.get_node("BuffManager") as BuffManager).has_buff("poison"), "Tea failed fatigue/poison interaction")
	survival.begin_eating("dirty_water")
	work.tick(1)
	var poisoned_hp := game.player.health_component.hp
	(game.player.get_node("BuffManager") as BuffManager).tick(1)
	check(poisoned_hp - game.player.health_component.hp == 3, "Dirty water poison scaled with the drinker's magic attribute")
	(game.player.get_node("BuffManager") as BuffManager).remove_status("poison")
	game.player.health_component.hp = 31
	game.player.mana_component.mp = 7
	var snapshot := survival.serialize()
	check(SaveManager.instance.save_game(2), "Survival state could not save")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true,true)
	GameRuntime.instance.set_process(false)
	check(game.survival.needs.serialize() == _without_vitals(snapshot) and game.player.health_component.hp == 31 and game.player.mana_component.mp == 7, "Cold load refilled vitals or lost needs/timers")
	await fixture.close()
	if errors.is_empty(): print("Survival world passed: live interrupted use, atomic cooking, real fire/fuel substitution, extinguish rollback, discovery, regenerative harvest, water facts, permanent repair and disk recovery")
	quit(0 if errors.is_empty() else 1)
func _without_vitals(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result.erase("hp")
	result.erase("mp")
	return result
