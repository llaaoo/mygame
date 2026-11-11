extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var game: MVPGame
var errors: Array[String] = []
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func cast(id: String, point: Vector2) -> void:
	var sm := game.player.skill_manager
	var action := sm.pool.get_skill(id)
	sm.equip_slot(0, action)
	var context := CastContext.at_position(game.player, point, action) if action.ground_targeted else CastContext.simple(game.player, Vector2.RIGHT, action)
	check(sm.use_source("slot_0", game.player, context), "Normal-budget cast rejected: " + id)
	GameRuntime.instance.get_simulation_runtime().tick(1.0 if not action.field_type.is_empty() else .9)
	for i in range(5): await physics_frame
	if id == "ignite": await create_timer(.3).timeout
func _run() -> void:
	var measurements: Array[Dictionary] = []
	for label in ElementTrialRecorder.LABELS:
		var fixture := Fixture.new(self)
		game = await fixture.boot()
		check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
		GameRuntime.instance.set_process(false)
		var player := game.player
		var sm := player.skill_manager
		sm.restrict_actions = false
		sm.combinations.learned_rules.storm_sigil_spark = true
		var supplies := sm.combinations.supplies
		# Equal, limited supplies already offered by the chapter. No increased caps,
		# healing, mana refills, free attacks or cooldown resets during a sample.
		supplies.restore({"amounts": {"frost_salt": 3, "storm_dust": 3, "venom_extract": 3}})
		check(player.health_component.max_hp == 100 and player.mana_component.max_mp == 60, "Normal-budget sample changed character caps")
		check(game.trial_recorder.start(label), "Normal-budget recorder did not start")
		game._change_region("archive")
		player.mana_component.mp_regen_rate = 0
		player.health_component.regen_rate = 0
		for enemy in game.active_enemies:
			enemy.set_physics_process(false)
			enemy.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
		var target := game.active_enemies[0]
		var target_health := target.health_component
		var target_buffs := target.get_node("BuffManager") as BuffManager
		check(target_health.max_hp == 32, "Normal-budget sample inflated authored enemy health")
		var point := target.global_position
		player.global_position = point - Vector2(120 if label == "导电布场" else 48, 0)
		await physics_frame
		match label:
			"冻结控制":
				supplies.configure("water_call", "frost_salt")
				await cast("water_call", point)
				check(target_buffs.has_buff("frozen"), "Normal-budget freeze failed")
				player.combat_component.perform_melee_attack(Vector2.RIGHT)
				await create_timer(.2).timeout
				check(target_buffs.has_buff("frozen"), "Normal-budget ordinary melee lost control")
			"破冰兑现":
				supplies.configure("water_call", "frost_salt")
				await cast("water_call", point)
				await cast("pulse", point)
				check(game.progress.verified_reactions.has("hit:shatter") and (not is_instance_valid(target_buffs) or not target_buffs.has_buff("frozen")), "Normal-budget shatter did not spend control")
			"导电布场":
				supplies.configure("water_call", "storm_dust")
				await cast("water_call", point)
				# Retreat to an actually dry cell before preparing a sigil. The
				# authored archive pool also conducts, including nearby left cells.
				player.global_position = point - Vector2(224, 0)
				var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
				check(surfaces.surface_at(player.global_position).state == "dry", "Conduction preparation requires a dry landing")
				surfaces.tick_entity_surface()
				check(target_buffs.has_buff("wet") and target_buffs.has_buff("shocked"), "Normal-budget conduction lost target exposure")
				await cast("storm_sigil", point)
				await cast("ignite", point)
			"污染引燃":
				supplies.configure("water_call", "venom_extract")
				await cast("water_call", point)
				check(target_buffs.has_buff("poison"), "Normal-budget poison setup failed")
				await cast("ignite", point)
				if is_instance_valid(target_buffs) and not target_health.is_dead:
					check(not target_buffs.has_buff("poison") and target_buffs.has_buff("burning"), "Normal-budget ignition did not consume poison")
		var record := game.trial_recorder.finish("正常预算受控战术检查")
		var expected_cost: int = {"冻结控制": 7, "破冰兑现": 10, "导电布场": 29, "污染引燃": 12}[label]
		check(record.mana_spent == expected_cost and player.mana_component.mp == 60 - expected_cost and not player.health_component.is_dead, "Normal-budget sample leaked resources or exhausted the character: " + label)
		check(record.initial.max_hp == 100 and record.initial.max_mp == 60 and record.damage_dealt > 0 and record.regions == ["camp", "archive"], "Normal-budget measurements lost actual costs/damage/route")
		var summary := {"configuration": label, "seconds": record.seconds, "casts": record.casts, "melee": record.melee, "damage_dealt": record.damage_dealt, "damage_taken": record.damage_taken, "mana_spent": record.mana_spent, "materials": record.materials, "remaining_hp": player.health_component.hp, "remaining_mp": player.mana_component.mp}
		measurements.append(summary)
		print("Normal-budget measurement: " + JSON.stringify(summary))
		await fixture.close()
	var file := FileAccess.open("user://normal_budget_tactics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "controlled interaction samples, not full-route playthroughs", "measurements": measurements}, "\t"))
	file.close()
	if errors.is_empty(): print("Normal-budget tactics passed: equal limited supplies, 100HP/60MP, authored 32HP guards, real spells/melee and recorded tradeoffs; full route pacing remains a playtest task")
	quit(0 if errors.is_empty() else 1)
