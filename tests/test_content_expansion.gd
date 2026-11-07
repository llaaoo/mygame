extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
var game: MVPGame
const REGIONS := ["archive", "drain", "cistern"]
const CLAIMS := ["magic.charged_crystal", "magic.thermal_cache", "magic.waterworks_conductor"]
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func frames(count := 4) -> void:
	for i in range(count): await process_frame
func puzzle(id: String) -> SpellWorldObject:
	for node in game.region_root.get_children():
		if node is SpellWorldObject and node.spec.id == id: return node
	return null
func shortcut() -> ExplorationExitData:
	for exit in game.current_data.exits:
		if not exit.required_claims.is_empty(): return exit
	return null
func freeze_enemies() -> void:
	for enemy in game.active_enemies:
		enemy.set_physics_process(false)
		enemy.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
func travel(id: String) -> void:
	game._change_region(id)
	freeze_enemies()
	await frames()
func observe(region: String) -> void:
	for note in game.current_data.discoveries:
		if note.id == "field." + region + "_observation":
			var inventory := game.player.skill_manager.combinations.supplies.serialize()
			var verified := game.progress.verified_reactions.duplicate()
			check(game.progress_service.discover(note), "New observation unavailable: " + region)
			check(not game.progress_service.discover(note) and inventory == game.player.skill_manager.combinations.supplies.serialize(), "Observation duplicated or granted supplies")
			check(game.progress.verified_reactions == verified, "Reading an observation falsely verified a reaction")
func cast(id: String, target: Vector2) -> void:
	var sm := game.player.skill_manager
	var action := sm.pool.get_skill(id)
	sm.combinations.cooldowns.clear()
	sm.combinations.tick(.5)
	sm.equip_slot(0, action)
	game.player.global_position = target - Vector2(24, 0)
	var context := CastContext.at_position(game.player, target, action)
	context.direction = Vector2.RIGHT
	check(sm.use_source("slot_0", game.player, context), "Content cast rejected: " + id)
	sm.combinations.tick(.5)
	await create_timer(.5).timeout
func probe(spec: SpellPuzzleData) -> SpellWorldObject:
	var node := SpellWorldObject.new()
	node.spec = spec.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	node.spec.id = "test.alternative"
	node.position = Vector2(-160, 160)
	game.region_root.add_child(node)
	return node
func _run() -> void:
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	var sm := game.player.skill_manager
	sm.restrict_actions = false
	var supplies := sm.combinations.supplies
	var encounter_count := 0
	var puzzle_count := 0
	var new_notes := 0
	var shortcuts := 0
	for region: ExplorationRegionData in game.catalog.regions.values():
		encounter_count += region.encounters.size()
		puzzle_count += region.spell_objects.size()
		for note in region.discoveries:
			if note.id.begins_with("field."): new_notes += 1
		for exit in region.exits:
			if not exit.required_claims.is_empty(): shortcuts += 1
	check(game.catalog.regions.size() == 9 and game.catalog.actions.size() == 11 and game.catalog.spell_rules.size() == 24 and supplies.catalog.size() == 7 and supplies.crafting_recipes.size() == CastingSupplies.MATERIAL_IDS.size()+SpellOperationCatalog.default_catalog().recipes.size() and game.catalog.equipment.size() == 4 and encounter_count == 18 and puzzle_count == 10, "Content expansion inflated core catalogs")
	check(new_notes == 3 and shortcuts == 3 and game.quests.size() == 5, "Expansion grants/shortcuts/quest registration incomplete")
	var quest: ExplorationQuestData
	for entry in game.quests:
		if entry.id == "field_research": quest = entry
	check(quest != null and not game.progress_service.claim_quest(quest), "Incomplete field research awarded points")
	for region in REGIONS:
		await travel(region)
		var exit := shortcut()
		check(exit != null and not exit.claims_satisfied(game.progress), "Shortcut was not initially locked")
		game._use_exit(exit)
		await frames()
		check(game.region_id == region and game.ui.message.text == exit.locked_message, "Locked shortcut travelled or hid its condition")
		for i in range(game.current_data.encounters.size()):
			var spec := game.current_data.encounters[i]
			var actor := game.active_enemies[i]
			var profile := spec.profile
			check(profile != null and actor.get_meta("encounter_profile") == profile.id and actor.enemy_type == profile.appearance_preset and actor.ai_role == profile.role, "Enemy profile was applied too late or lost identity")
			check(actor.max_hp == spec.hp and actor.health_component.hp == spec.hp and is_equal_approx(actor.move_speed, spec.speed), "Enemy profile overrode encounter HP/speed")
			check(actor.attack_damage == profile.melee_damage and is_equal_approx(actor.attack_cooldown, profile.melee_cooldown) and actor.attack_range == profile.attack_range and actor.ranged_preferred_range == profile.ranged_preferred_range, "Enemy combat parameters were overwritten on ready")
			check(actor.surface_awareness.cautious == (profile.role == Enemy.AIRole.RANGED), "Profile role disagrees with surface steering")
			check(actor.skill_manager.right_hand.data.get_id() == "shadow_bolt" and actor.skill_manager.right_hand.data.damage == sm.pool.get_skill("shadow_bolt").damage and actor.skill_manager.right_hand.data.cooldown == sm.pool.get_skill("shadow_bolt").cooldown, "Profile changed the ranged spell")
		# Pure helpers accept only all required claims; old conditions remain conjunctive.
		var both := exit.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ExplorationExitData
		both.required_claims.append("field." + region + "_observation")
		game.progress.claims[exit.required_claims[0]] = true
		check(not both.claims_satisfied(game.progress), "Multiple completion conditions were ORed")
		game.progress.claims.erase(exit.required_claims[0])
	# Unprofiled defaults and the existing cooling branch remain effective.
	await travel("yard")
	check(game.active_enemies[0].attack_damage == 9 and game.active_enemies[0].enemy_type == 0, "Unprofiled encounter changed")
	game.progress.choices.waterworks_choice = "cooling"
	await travel("boss")
	check(game.active_enemies[0].max_hp == 210 and game.active_enemies[0].attack_damage == 15 and is_equal_approx((game.active_enemies[0] as Boss).boss_data.resists.fire, .1), "Ordinary profiles changed the cooled boss")
	game.progress.choices.clear()
	# First-visit archive route uses ordinary fire/pulse and zero consumables.
	await travel("camp")
	await travel("archive")
	observe("archive")
	var archive := puzzle(CLAIMS[0])
	var mana := game.player.mana_component.mp
	await cast("pulse", archive.global_position)
	check(not archive.completed, "Impact alone bypassed archive sequence")
	await cast("ignite", archive.global_position)
	await cast("pulse", archive.global_position)
	check(archive.completed and game.progress.claims.has(CLAIMS[0]) and shortcut().claims_satisfied(game.progress) and "捷径已开启" in game.ui.message.text, "Fire/impact did not open archive shortcut")
	check(mana - game.player.mana_component.mp == 10 and supplies.count("storm_dust") == 2 and supplies.count("crystal") == 2, "Archive solution costs or unchanged reward incorrect")
	check(not game.progress_service.solve_puzzle(archive.spec), "Solved archive rewarded twice")
	# Both new cold/impact and original lightning paths execute on real hitboxes.
	var cold := probe(archive.spec)
	supplies.grant({"frost_salt": 1})
	supplies.configure("water_call", "frost_salt")
	await cast("water_call", cold.global_position)
	check(not cold.completed, "Ice alone bypassed impact requirement")
	await cast("pulse", cold.global_position)
	check(cold.completed, "Cold/impact archive alternative failed")
	cold.queue_free()
	supplies.configure("water_call", "")
	var lightning := probe(archive.spec)
	CombatExecutor.report_hit(game.player, lightning, 0, lightning.global_position, sm.pool.get_skill("storm_bolt"), ["lightning"])
	check(lightning.completed, "Original lightning archive alternative broke")
	lightning.queue_free()
	var exit := shortcut()
	var guarded := exit.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ExplorationExitData
	guarded.requires_clear = true
	game._use_exit(guarded)
	check(not game._switching, "Completion marker bypassed clear condition")
	guarded.requires_clear = false
	guarded.required_action = "focus"
	game._use_exit(guarded)
	check(not game._switching, "Completion marker bypassed knowledge condition")
	game._use_exit(exit)
	await frames(8)
	check(game.region_id == "camp", "Archive shortcut failed while guards remained")
	# A real steam surface must hold continuously; no material is required.
	await travel("drain")
	observe("drain")
	var thermal := puzzle(CLAIMS[1])
	await cast("water_call", thermal.global_position)
	await cast("ignite", thermal.global_position)
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	var receiver_cell := SurfaceManager.cell_at(thermal.global_position)
	check(surfaces.get_surface(receiver_cell).state == "steam", "Water/fire did not create actual steam at thermal cache")
	thermal.tick(.25)
	check(not thermal.completed, "Steam shortcut skipped hold time")
	surfaces.force_set_surface(receiver_cell, "wet", 12)
	thermal.tick(.3)
	await cast("ignite", thermal.global_position)
	thermal.tick(.49)
	check(not thermal.completed, "Interrupted steam condition kept stale hold progress")
	thermal.tick(.01)
	check(thermal.completed and shortcut().claims_satisfied(game.progress), "Continuous steam did not open thermal shortcut")
	game._use_exit(shortcut())
	await frames(8)
	check(game.region_id == "camp", "Thermal shortcut did not return to camp")
	# Remote conduction, not direct tags, unlocks the independent cistern exit.
	await travel("cistern")
	observe("cistern")
	var receiver := puzzle(CLAIMS[2])
	CombatExecutor.report_hit(game.player, receiver, 0, receiver.global_position, sm.pool.get_skill("storm_bolt"), ["lightning"])
	receiver.tick(1)
	check(not receiver.completed, "Dry receiver accepted direct lightning")
	var valve: SurfaceValve
	for node in game.region_root.get_children():
		if node is SurfaceValve: valve = node
	valve.cycle()
	supplies.configure("water_call", "storm_dust")
	var dust := supplies.count("storm_dust")
	await cast("water_call", Vector2(-160, 96))
	check(surfaces.get_surface(SurfaceManager.cell_at(receiver.global_position)).state == "electrified", "Remote water payload failed to reach the receiver")
	receiver.tick(.49)
	check(not receiver.completed, "Conductor shortcut skipped hold time")
	receiver.tick(.01)
	check(receiver.completed and shortcut().claims_satisfied(game.progress) and not game.progress.choices.has("waterworks_choice") and supplies.count("storm_dust") == dust, "Conductor reward/shortcut depended on old water choice or duplicated costs")
	game._use_exit(shortcut())
	await frames(8)
	check(game.region_id == "camp", "Independent conductor shortcut failed")
	var points := game.player.stats_component.attribute_points
	check(game.progress_service.claim_quest(quest) and game.player.stats_component.attribute_points == points + 1, "Field research did not award exactly one point")
	check(not game.progress_service.claim_quest(quest) and game.player.stats_component.attribute_points == points + 1, "Field research awarded twice")
	var saved_supplies := supplies.serialize()
	check(SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Expansion progress save failed")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	check(game.progress.claims.has("quest.field_research") and game.player.stats_component.attribute_points == points + 1 and game.player.skill_manager.combinations.supplies.serialize() == saved_supplies, "Fresh disk restore lost points/claims/supplies")
	for i in range(REGIONS.size()):
		await travel(REGIONS[i])
		check(puzzle(CLAIMS[i]).completed and shortcut().claims_satisfied(game.progress), "Saved shortcut was relocked")
		check(not game.progress_service.solve_puzzle(puzzle(CLAIMS[i]).spec), "Disk restore duplicated puzzle reward")
	# Old completion markers unlock new shortcuts without re-granting rewards.
	var legacy := game.progress.serialize_save_data()
	for region in REGIONS: legacy.claims.erase("field." + region + "_observation")
	legacy.claims.erase("quest.field_research")
	game.progress.deserialize_save_data(legacy)
	var inventory := game.player.skill_manager.combinations.supplies.serialize()
	for i in range(REGIONS.size()):
		game.progress.cleared[REGIONS[i]] = true
		await travel(REGIONS[i])
		check(game.active_enemies.is_empty() and shortcut().claims_satisfied(game.progress), "Old cleared region respawned or failed to unlock shortcut")
		check(game.player.skill_manager.combinations.supplies.serialize() == inventory, "Old markers re-granted materials")
	# Death and encounter replay preserve latched shortcuts while resetting combat.
	game.player.health_component.invincible = false
	CombatExecutor.report_hit(null, game.player, 999, game.player.global_position, null, ["environment"])
	check(game.ui.modal_locked and game.progress.claims.has(CLAIMS[2]), "Death discarded mechanism completion")
	game.ui.close_modal()
	game.progress_service.replay_encounters()
	await frames(8)
	await travel("archive")
	check(game.active_enemies.size() == 3 and shortcut().claims_satisfied(game.progress), "Encounter reset lost shortcut or did not restore configured enemies")
	check("机关检修捷径" in game.journal_text(), "Journal omitted persistent shortcuts")
	await fixture.close()
	if errors.is_empty(): print("Content expansion passed: unchanged core catalogs, profiles, alternatives, continuous steam, remote conduction, conjunctive exits, once-only field quest, disk/legacy/death/replay")
	quit(0 if errors.is_empty() else 1)
