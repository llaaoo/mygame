extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
var game: MVPGame
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func cast(skill_id: String, point: Vector2) -> void:
	var sm := game.player.skill_manager
	var skill := sm.pool.get_skill(skill_id)
	sm.equip_slot(0, skill)
	sm.combinations.cooldowns.clear()
	var context := CastContext.at_position(game.player, point, skill) if skill.ground_targeted else CastContext.simple(game.player, Vector2.RIGHT, skill)
	check(sm.use_source("slot_0", game.player, context), "Trial cast did not start: " + skill_id)
	GameRuntime.instance.get_simulation_runtime().tick(1.0 if not skill.field_type.is_empty() else .9)
	for i in range(5): await physics_frame
	if skill_id == "ignite": await create_timer(.3).timeout

func _run() -> void:
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(false)
	for label in ElementTrialRecorder.LABELS:
		game._change_region("camp")
		var player := game.player
		var sm := player.skill_manager
		sm.restrict_actions = false
		sm.combinations.learned_rules["storm_sigil_spark"] = true
		player.health_component.max_hp = 1000
		player.health_component.hp = 1000
		player.health_component.regen_rate = 0
		player.mana_component.max_mp = 1000
		player.mana_component.mp = 1000
		player.mana_component.mp_regen_rate = 0
		var supplies := sm.combinations.supplies
		supplies.restore({"amounts": {"frost_salt": 20, "storm_dust": 20, "venom_extract": 20}})
		check(game.trial_recorder.start(label), "Trial recording failed to start")
		check(not game.trial_recorder.start(label), "A second start overwrote the active measurement")
		game._change_region("archive")
		player.global_position = Vector2(26016, 26016)
		var target := load("res://entities/enemy/enemy.tscn").instantiate() as Enemy
		target.position = player.position + Vector2(120 if label == "导电布场" else 48, 0)
		game.region_root.add_child(target)
		target.set_physics_process(false)
		target.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
		target.health_component.max_hp = 1000
		target.health_component.hp = 1000
		target.health_component.regen_rate = 0
		await physics_frame
		var buffs := target.get_node("BuffManager") as BuffManager
		var mana := player.mana_component.mp
		match label:
			"冻结控制":
				supplies.configure("water_call", "frost_salt")
				await cast("water_call", target.global_position)
				check(buffs.has_buff("frozen"), "Control configuration failed to prepare freeze")
				player.combat_component.perform_melee_attack(Vector2.RIGHT)
				await create_timer(.2).timeout
				check(buffs.has_buff("frozen"), "Ordinary melee consumed frozen preparation")
			"破冰兑现":
				supplies.configure("water_call", "frost_salt")
				await cast("water_call", target.global_position)
				await cast("pulse", target.global_position)
				check(not buffs.has_buff("frozen") and target.health_component.hp < 1000, "Shatter configuration did not exchange control for damage")
			"导电布场":
				supplies.configure("water_call", "storm_dust")
				await cast("water_call", target.global_position)
				var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
				surfaces.tick_entity_surface()
				check(buffs.has_buff("wet") and buffs.has_buff("shocked"), "Conductive configuration lost wet/shocked exposure")
				await cast("storm_sigil", target.global_position)
				await cast("ignite", target.global_position)
				check(target.health_component.hp < 1000, "Conductive configuration failed to follow terrain preparation with a real projectile")
			"污染引燃":
				supplies.configure("water_call", "venom_extract")
				await cast("water_call", target.global_position)
				check(buffs.has_buff("poison"), "Contamination configuration failed to prepare poison")
				await cast("ignite", target.global_position)
				check(not buffs.has_buff("poison") and buffs.has_buff("burning"), "Ignition configuration did not consume poison")
		player.health_component.invincible = false
		CombatExecutor.report_hit(target, player, 12, player.global_position, null, ["melee", "enemy"])
		var result := game.trial_recorder.finish("自动化配置回归")
		if label in ["破冰兑现", "污染引燃"]:
			check(result.surface_steps.any(func(step): return step.has("skill") and not step.get("prior_target_statuses", []).is_empty() and step.get("consumed", false)), "Reaction history lost actual tool, prior condition or consumption")
		check(result.regions == ["camp", "archive"] and result.seconds > 0 and result.casts > 0, "Recorder lost elapsed time, operations or region sequence")
		check(result.mana_spent == mana - player.mana_component.mp and result.materials.size() > 0 and result.damage_dealt > 0 and result.damage_taken >= 12, "Recorder did not measure actual costs and accepted damage")
		check(result.initial.max_hp == 1000 and result.initial.supplies.amounts.frost_salt == 20, "Comparable trial did not retain its starting budget")
		print("Trial measurement: " + JSON.stringify({"configuration": result.label, "seconds": result.seconds, "casts": result.casts, "melee": result.melee, "damage_dealt": result.damage_dealt, "damage_taken": result.damage_taken, "mana_spent": result.mana_spent, "materials": result.materials}))
	game.trial_recorder.show_page()
	check(is_instance_valid(game.ui.modal), "Trial comparison UI failed")
	game.ui.close_modal()
	check(game.progress.trial_runs.size() == 4 and SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Trial history save failed")
	check(game.trial_recorder.start("冻结控制"), "Death recording did not start")
	game.player.health_component.hp = 12
	game.player.health_component.invincible = false
	CombatExecutor.report_hit(null, game.player, 999, game.player.global_position, null, ["environment"])
	for i in range(3): await process_frame
	check(not game.trial_recorder.active and game.progress.trial_runs.size() == 5 and game.progress.trial_runs.back().damage_taken == 12 and game.progress.trial_runs.back().result == "死亡中断", "Death ended the recorder before the fatal damage was measured")
	var saved := SaveManager.instance.read_extension(MVPGame.SAVE_SLOT, MVPGame.SECTION)
	check(ExplorationProgress.new().validate_save_data(saved), "Recorder generated invalid progress")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	check(game.progress.trial_runs.size() == 5 and not game.trial_recorder.active, "Fresh restore lost history or resumed stale recording")
	check(not ExplorationProgress.new().validate_save_data({"trial_runs": [{"label": "bad", "seconds": -1}]}), "Malformed trial progress accepted")
	await fixture.close()
	if errors.is_empty(): print("Element trials passed: four real configurations, retained/consumed conditions, committed operation/cost/damage measurements, UI and disk history")
	quit(0 if errors.is_empty() else 1)
