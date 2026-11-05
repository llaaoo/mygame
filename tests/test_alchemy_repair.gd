extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var game: MVPGame
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func frames(count := 4) -> void:
	for i in range(count): await process_frame
func travel(id: String) -> void:
	game.ui.close_modal()
	game._change_region(id)
	for enemy in game.active_enemies:
		enemy.set_physics_process(false)
		enemy.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
	await frames()
func site(id: String) -> SpellWorldObject:
	for node in game.region_root.get_children():
		if node is SpellWorldObject and node.spec.id == id: return node
	return null
func facility() -> ExplorationInteractable:
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.title.begins_with("重启调和台"): return node
	return null
func hit(node: SpellWorldObject, tag: String) -> void:
	CombatExecutor.report_hit(game.player, node, 0, node.global_position, null, [tag])
func cast(id: String, target: Vector2) -> void:
	var sm := game.player.skill_manager
	var skill := sm.pool.get_skill(id)
	sm.combinations.tick(.8)
	sm.equip_slot(0, skill)
	game.player.global_position = target - Vector2(24, 0)
	var context := CastContext.at_position(game.player, target, skill)
	context.direction = Vector2.RIGHT
	check(sm.use_source("slot_0", game.player, context), "Task spell failed: " + id)
	sm.combinations.tick(.8)
	await create_timer(.3).timeout
func run() -> void:
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	var player := game.player
	var work := player.field_work
	var supplies := player.skill_manager.combinations.supplies
	var quest: ExplorationQuestData
	for entry in game.quests:
		if entry.id == "alchemy_repair": quest = entry
	check(quest != null and not game.workshop.recycling_available() and not game.progress_service.claim_quest(quest), "Old save/new quest default was not unfinished")
	await travel("drain")
	var pump := site(AlchemyRepairService.PUMP)
	for tag in ["fire", "water", "impact"]: hit(pump, tag)
	check(not pump.completed, "Spell route ignored missing schematic")
	game.player.global_position = pump.global_position
	game.field_sites.inspect(pump)
	check(not paused and not player.ui_blocked and not work.start_selected(), "Work inspection paused or ignored diagram")
	await travel("archive")
	for note in game.current_data.discoveries:
		if note.id == "alchemy.schematic": check(game.progress_service.discover(note), "Diagram unavailable before accepting task")
	check(not game.progress.claims.has("alchemy.started"), "Diagram implicitly accepted task")
	# Unfinished ordered spell hits disappear on region leave.
	await travel("drain")
	pump = site(AlchemyRepairService.PUMP)
	hit(pump, "fire")
	await travel("archive")
	await travel("drain")
	pump = site(AlchemyRepairService.PUMP)
	hit(pump, "water")
	hit(pump, "impact")
	check(not pump.completed, "Partial spell sequence survived region leave")
	# Real utility hits complete the no-consumable route, with ordinary 100/60 caps.
	player.skill_manager.restrict_actions = false
	var inventory := supplies.serialize()
	check(player.health_component.max_hp == 100 and player.mana_component.max_mp == 60, "Task spell test inflated character caps")
	await cast("ignite", pump.global_position)
	await cast("water_call", pump.global_position)
	await cast("pulse", pump.global_position)
	check(pump.completed and game.progress.choices[AlchemyRepairService.PUMP] == "thermal_impact" and supplies.serialize() == inventory, "Real fire/water/impact route failed or consumed material")
	check(not game.progress.claims.has("alchemy.pump_taken"), "Opened pump teleported task part")
	var surfaces := SurfaceManager.instance
	check(surfaces.surface_at(Vector2(96, 32)).state == "wet", "Pump did not wash authored poison through water rule")
	player.position = Vector2(-200, 0)
	check(not game.field_sites.take_part(pump), "Task part picked up remotely")
	player.position = pump.position
	check(game.field_sites.take_part(pump) and not game.field_sites.take_part(pump), "Pump pickup duplicated")
	await travel("archive")
	await travel("drain")
	check(surfaces.surface_at(Vector2(96, 32)).get("state", "dry") == "dry" and site(AlchemyRepairService.PUMP).part_taken, "Permanent poison source or part respawned")
	# Material method: delayed payment and competing steam solution share authority.
	await travel("cistern")
	var regulator := site(AlchemyRepairService.REGULATOR)
	player.position = regulator.position
	game.field_sites.inspect(regulator)
	check(not work.start_selected(), "Intelligence gate ignored")
	work.selected = 1
	check(not work.start_selected(), "Material gate ignored")
	supplies.grant({"resin": 2, "crystal": 4})
	inventory = supplies.serialize()
	check(work.start_selected(), "Material method failed to start")
	work.tick(1)
	check(inventory == supplies.serialize(), "Material method paid before completion")
	player.health_component.invincible = false
	CombatExecutor.report_hit(null, player, 1, player.position, null, ["test"])
	check(not work.is_busy() and inventory == supplies.serialize(), "Damage interruption leaked materials")
	check(work.start_selected(), "Material method could not restart")
	game.trial_recorder.start("冻结控制")
	work.tick(1.5)
	var trial := game.trial_recorder.finish("受控检修检查")
	check(regulator.completed and supplies.count("resin") == 1 and supplies.count("crystal") == 2 and trial.work_actions == 1 and trial.materials == {"resin": 1, "crystal": 2}, "Task material commit/trial count incorrect")
	check(surfaces.surface_at(regulator.position).state == "steam" and is_equal_approx(float(surfaces.surface_at(regulator.position).remaining), 6), "Regulator did not release six seconds of steam")
	check(game.field_sites.take_part(regulator), "Regulator pickup failed")
	# Assembly rejects missing acceptance, then uses the same interruptible state.
	await travel("camp")
	var bench := facility()
	player.position = bench.position
	check(not game.progress.claims.has("alchemy.started"), "Parts required early acceptance")
	bench.callback.call()
	check(game.progress.claims.has("alchemy.started") and not paused and not player.ui_blocked, "Facility acceptance paused or failed")
	inventory = supplies.serialize()
	check(work.start_selected(), "Complete task could not assemble")
	work.tick(2.9)
	check(not game.workshop.recycling_available(), "Assembly completed early")
	work.tick(.1)
	check(game.workshop.recycling_available() and supplies.serialize() == inventory, "Assembly charged extra material or did not unlock permanent recycling")
	var points := player.stats_component.attribute_points
	check(game.progress_service.claim_quest(quest) and not game.progress_service.claim_quest(quest) and player.stats_component.attribute_points == points + 1, "Repair reward duplicated")
	check("材料密封修补" in game.journal_text() and "火→水→冲击" in game.journal_text(), "Actual completion methods missing from journal")
	check(SaveManager.instance.save_game(2), "Task progress could not save")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	surfaces = SurfaceManager.instance
	check(game.workshop.recycling_available() and game.progress.claims.has("quest.alchemy_repair") and game.progress.claims.has("alchemy.pump_taken") and game.progress.claims.has("alchemy.regulator_taken"), "Repaired task failed disk restore")
	game.progress_service.replay_encounters()
	await frames(8)
	check(game.workshop.recycling_available() and game.progress.claims.has("alchemy.regulator_taken"), "Encounter replay erased permanent repair")
	await travel("cistern")
	check(site(AlchemyRepairService.REGULATOR).completed and site(AlchemyRepairService.REGULATOR).part_taken and surfaces.surface_at(Vector2(160,-224)).get("state", "dry") == "dry", "Restore/replay repeated regulator steam or parts")
	game.player.skill_manager.restrict_actions = false
	# Independent condition probes reuse the same registered sites. These are
	# contracts, not balance measurements; the desktop playtest uses earned points.
	game.progress.claims.erase(AlchemyRepairService.PUMP)
	game.progress.claims.erase(AlchemyRepairService.REGULATOR)
	await travel("drain")
	pump = site(AlchemyRepairService.PUMP)
	player = game.player
	work = player.field_work
	player.position = pump.position
	game.field_sites.inspect(pump)
	check(not work.start_selected(), "Default attributes bypassed pump force gate")
	player.stats_component.modify_stat("strength", 4)
	check(work.start_selected(), "Effective strength14 could not start force method")
	work.tick(1.99)
	check(not pump.completed, "Force operation applied spell preparation acceleration")
	work.tick(.01)
	check(pump.completed and game.progress.choices[AlchemyRepairService.PUMP] == "force", "Force route failed fixed two-second completion")
	await travel("cistern")
	regulator = site(AlchemyRepairService.REGULATOR)
	player.position = regulator.position
	game.field_sites.inspect(regulator)
	player.stats_component.modify_stat("intelligence", 4)
	check(work.start_selected(), "Intelligence14 could not calibrate")
	work.tick(2.49)
	check(not regulator.completed, "Calibration completed before fixed2.5sec")
	work.tick(.01)
	check(regulator.completed and game.progress.choices[AlchemyRepairService.REGULATOR] == "calibrate", "Calibration completion failed")
	game.progress.claims.erase(AlchemyRepairService.REGULATOR)
	await travel("drain")
	await travel("cistern")
	regulator = site(AlchemyRepairService.REGULATOR)
	for tag in ["water", "fire"]: hit(regulator, tag)
	regulator.tick(.5)
	check(not regulator.completed, "Hit tags substituted for actual steam")
	await cast("water_call", regulator.position)
	await cast("ignite", regulator.position)
	regulator.tick(.49)
	check(not regulator.completed, "Steam hold completed early")
	surfaces.force_set_surface(SurfaceManager.cell_at(regulator.position), "wet", 5)
	regulator.tick(.01)
	surfaces.force_set_surface(SurfaceManager.cell_at(regulator.position), "steam", 3)
	regulator.tick(.49)
	check(not regulator.completed, "Interrupted steam hold was retained")
	regulator.tick(.01)
	check(regulator.completed and game.progress.choices[AlchemyRepairService.REGULATOR] == "steam", "Actual continuous steam route failed")
	SurfaceManager.instance._surface_scheduler.tick(1)
	player.position = regulator.position
	game.progress.claims.erase("alchemy.regulator_taken")
	check(game.field_sites.take_part(regulator) and is_equal_approx(float(surfaces.surface_at(regulator.position).remaining), 5), "Pickup repeated regulator steam pulse")
	await fixture.close()
	if errors.is_empty(): print("Alchemy repair passed: diagram-first exploration, real spell/attribute/material conditions, live work, separate pickup, persistent environmental outcomes, assembly, once-only quest and replay/disk recovery")
	quit(0 if errors.is_empty() else 1)
