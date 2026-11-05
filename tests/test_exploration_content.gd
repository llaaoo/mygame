extends "res://tests/support/exploration_case.gd"
## Real interactions, combat physics, buff lifecycle, quest rewards and disk restore.

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(10)
	game.ui.close_modal()
	_check(game.quests.size() == 4, "Camp quests missing")
	var points := game.player.stats_component.attribute_points
	game._claim_quest(game.quests[0])
	_check(game.player.stats_component.attribute_points == points and not game.progress.claims.has("quest.rescue"), "Incomplete quest awarded points")
	game.ui.close_modal()
	await _travel("yard")
	await _interact("火阵铭刻记录")
	game.ui.close_modal()
	await _clear_encounter()
	await _travel("archive")
	await _interact("被困的测绘员")
	_check(not game.progress.claims.has("cartographer_rescued") and not paused, "Rescue bypassed living guards")
	await _interact("震荡与焰环")
	game.ui.close_modal()
	await _clear_encounter()
	await _interact("被困的测绘员")
	game.ui.close_modal()
	_check(game.progress.claims.has("cartographer_rescued"), "Rescue did not record world change")
	await _interact("深层支路：静默祈堂")
	_check(game.region_id == "sanctum" and game.active_enemies.size() == 3, "Sanctum branch encounter missing")
	await _interact("凝神碑")
	_check(not game.progress.actions.has("focus"), "Guarded knowledge awarded before clear")
	await _clear_encounter()
	var sm := game.player.skill_manager
	sm.equip_hand("left", sm.pool.get_skill("pulse"))
	sm.unequip_slot(0)
	await _interact("凝神碑")
	game.ui.close_modal()
	_check(sm.known_actions.has("focus") and sm.get_slot(1).data.get_id() == "focus", "Focus not taught/equipped")
	_check(sm.left_hand.data.get_id() == "pulse" and sm.get_slot(0) == null, "New discovery overwrote custom loadout")
	await _travel("camp")
	points = game.player.stats_component.attribute_points
	await _interact("测绘员艾妲")
	_check(paused, "Rescued NPC did not appear in camp")
	game._claim_quest(game.quests[0])
	_check(game.player.stats_component.attribute_points == points + 1, "Rescue reward missing")
	game._claim_quest(game.quests[0])
	_check(game.player.stats_component.attribute_points == points + 1, "Quest reward duplicated")
	game.ui.close_modal()
	await _travel("archive")
	var stranded := false
	for node in get_nodes_in_group("interactable"):
		if node is ExplorationInteractable and node.title.begins_with("被困的测绘员"):
			stranded = true
	_check(not stranded, "Rescued NPC remained stranded in archive")
	await _travel("powder")
	await _clear_encounter()
	await _travel("drain")
	await _interact("寒霜铭刻记录")
	game.ui.close_modal()
	await _clear_encounter()
	await _interact("深层支路：蓄水机房")
	_check(game.region_id == "cistern", "Cistern branch missing")
	var choices_before_valve := game.progress.choices.duplicate()
	await _interact("旧水路控制阀")
	_check(not paused and game.progress.choices == choices_before_valve and not game.progress.choices.has("waterworks_choice"), "Valve bypassed guards")
	await _clear_encounter()
	await _interact("寒霜新星试验记录")
	game.ui.close_modal()
	_check(game.progress.spell_rules.size() == 8, "Exploration did not grant all eight spell combinations")
	sm.equip_slot(0, sm.pool.get_skill("pulse"))

	# Range control must hit both sides and apply the existing frozen status.
	game.player.global_position = Vector2(12000, 12000)
	game.player.mana_component.max_mp = 300
	game.player.mana_component.mp = 300
	game.player.mana_component.mp_regen_rate = 0
	var front := _target(Vector2(70, 0))
	var back := _target(Vector2(-70, 0))
	_check(sm.use_slot(2, game.player, Vector2.RIGHT), "Frost field not started")
	await create_timer(0.9).timeout
	_check(sm.use_slot(0, game.player, Vector2.RIGHT), "Frost pulse not started")
	await create_timer(0.5).timeout
	_check(front.hits == 1 and back.hits == 1 and front.move_speed < 100 and back.move_speed < 100, "Frost nova missed targets or slow")
	_check(game.player.mana_component.mp == 280 and sm.combinations.field.charges == 1, "Frost nova cost/charge incorrect")
	sm.combinations.clear_field()
	var speed := game.player.move_speed
	var attack := game.player.combat_component.attack_damage
	var buffs: BuffManager = game.player.get_node("BuffManager")
	_check(sm.use_slot(1, game.player, Vector2.RIGHT), "Base focus not started")
	await create_timer(0.4).timeout
	_check(buffs.has_buff("focus") and is_equal_approx(game.player.move_speed, speed * 1.08), "Base focus did not apply haste")
	_check(game.player.mana_component.mp == 276, "Base focus mana incorrect")
	await create_timer(4.1).timeout
	_check(sm.use_slot(4, game.player, Vector2.RIGHT), "Fire field not started")
	await create_timer(0.9).timeout
	_check(sm.use_slot(1, game.player, Vector2.RIGHT), "Ember focus not started")
	await create_timer(0.4).timeout
	_check(buffs.has_buff("ember_focus") and not buffs.has_buff("focus") and game.player.combat_component.attack_damage == attack + 8, "Ember focus buff incorrect")
	_check(sm.combinations.field.charges == 1 and game.player.mana_component.mp == 258, "Buff combination cost/charge incorrect")
	# Result effects can be inspected but cannot be equipped or cast directly.
	var result := sm.pool.get_skill("ember_focus")
	sm.equip_slot(3, result)
	_check(sm.get_slot(3) == null and not sm._execute(result, "slot_3", game.player, Vector2.RIGHT), "Buff result bypassed combination")
	await create_timer(sm.get_cooldown("slot_2") + 0.1).timeout
	sm.combinations.clear_field() # This regression checks mutually exclusive buffs in isolation.
	_check(sm.use_slot(2, game.player, Vector2.RIGHT), "Replacement frost field not started")
	await create_timer(0.9).timeout
	await create_timer(3.1).timeout
	_check(sm.use_slot(1, game.player, Vector2.RIGHT), "Frost stride not started")
	await create_timer(0.4).timeout
	_check(buffs.has_buff("frost_stride") and not buffs.has_buff("ember_focus") and game.player.combat_component.attack_damage == attack, "Exclusive buff failed to remove melee bonus")
	_check(is_equal_approx(game.player.move_speed, speed * 1.3), "Frost stride speed incorrect")
	_check(game.player.mana_component.mp == 240, "Frost stride mana incorrect")
	# Growth during a speed buff must survive its removal without numerical drift.
	game.player.stats_component.modify_stat("agility", 1)
	speed += 3.0
	_check(is_equal_approx(game.player.move_speed, speed * 1.3), "Stat growth ignored active speed multiplier")
	var remaining: float = buffs.get_active_buff_entries()[0].remaining
	paused = true
	await create_timer(0.2, true).timeout
	_check(is_equal_approx(buffs.get_active_buff_entries()[0].remaining, remaining), "Pause advanced buff lifetime")
	paused = false
	await create_timer(8.2).timeout
	_check(not buffs.has_buff("frost_stride") and is_equal_approx(game.player.move_speed, speed), "Buff expiration did not restore speed")
	_check(sm.use_slot(1, game.player, Vector2.RIGHT), "Focus refresh did not start")
	await create_timer(0.4).timeout
	await _travel("camp")
	_check(buffs.get_active_buff_entries().is_empty() and is_equal_approx(game.player.move_speed, speed), "Region change leaked buff")

	# Both reversible choices affect a newly generated real Boss/region.
	await _travel("cistern")
	var event: ExplorationWorldEventData = game.current_data.events[0]
	await _interact("旧水路控制阀")
	_check(paused, "Cleared valve did not open choice panel")
	game._choose_world_event(event, event.choices[0])
	_check(game.progress.choices.get("waterworks_choice") == "cooling" and game.region_root.has_node("WaterworksShortcut"), "Cooling choice/shortcut missing")
	await _travel("boss")
	var boss := game.active_enemies[0] as Boss
	_check(boss.max_hp == 210 and boss.boss_data.resists.fire == 0.1, "Cooling did not weaken Boss")
	boss.health_component.invincible = false
	CombatExecutor.instance.reset_chain()
	CombatExecutor.report_hit(game.player, boss, 10, boss.global_position, null, ["fire"])
	_check(boss.health_component.hp == 201, "Boss cooling resistance did not affect real hit")
	await _travel("cistern")
	event = game.current_data.events[0]
	var entries := game.progress.journal.size()
	game._choose_world_event(event, event.choices[1])
	_check(game.progress.journal.size() == entries, "Rerouting duplicated journal entry")
	await _interact("检修梯：返回营地")
	_check(game.region_id == "camp" and game.player.mana_component.mp_regen_rate == 5, "Conduit did not improve regeneration")
	points = game.player.stats_component.attribute_points
	game._claim_quest(game.quests[1])
	game._claim_quest(game.quests[2])
	_check(game.player.stats_component.attribute_points == points + 4, "Waterworks/research quest rewards missing")
	game.ui.close_modal()
	_check(game.journal_text().contains("魔力导流") and game.journal_text().contains("已交付"), "Journal missing live world/quest state")
	await _interact("捷径：蓄水机房")
	_check(game.region_id == "cistern" and game.active_enemies.is_empty(), "Camp waterworks shortcut failed")
	await _travel("boss")
	_check(game.active_enemies[0].max_hp == 280 and (game.active_enemies[0] as Boss).boss_data.resists.fire == 0.3, "Rerouting retained cooling bonus")
	await _travel("camp")
	_check(SaveManager.instance.save_game(2), "Expanded progress save failed")
	var restored := ExplorationProgress.new()
	restored.deserialize_save_data(SaveManager.instance.read_extension(2, MVPGame.SECTION))
	_check(restored.choices.get("waterworks_choice") == "conduit" and restored.visited.has("sanctum") and restored.claims.has("quest.research") and restored.spell_rules.size() == 8, "Expanded progress not saved")
	sm.unequip_hand("left")
	game.reload_progress()
	await _frames()
	_check(game.region_id == "camp" and sm.left_hand != null and sm.left_hand.data.get_id() == "pulse", "Manual progress load did not restore custom hand")
	var legacy := ExplorationProgress.new()
	legacy.deserialize_save_data({"cleared": {"yard": true}})
	_check(legacy.visited.has("yard") and legacy.choices.is_empty() and legacy.actions.has("ignite"), "Old progress migration failed")
	game.queue_free()
	current_scene = null
	await _frames(5)
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(10)
	_check(game.progress.choices.get("waterworks_choice") == "conduit" and game.player.mana_component.mp_regen_rate == 5 and game.progress.spell_rules.size() == 8, "Fresh scene did not restore new content")
	game.ui.close_modal()
	points = game.player.stats_component.attribute_points
	game._claim_quest(game.quests[2])
	_check(game.player.stats_component.attribute_points == points, "Reload duplicated reward")
	game.ui.close_modal()
	game.replay_encounters()
	await _frames()
	_check(game.progress.claims.has("quest.research") and game.progress.choices.get("waterworks_choice") == "conduit" and game.progress.spell_rules.size() == 8, "Replay discarded persistent rewards/choices")
	await _travel("cistern")
	_check(game.active_enemies.size() == 3, "Replay did not rebuild expanded encounter")
	game.queue_free()
	current_scene = null
	await _frames(5)
	if errors.is_empty():
		print("Exploration content passed: new branches, rescue, six recipes, buff physics/lifecycle, reversible world choices, quests and disk restart")
	call_deferred("quit", 0 if errors.is_empty() else 1)
