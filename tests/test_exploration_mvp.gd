extends "res://tests/support/exploration_case.gd"

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(10)
	_check(game.ready_for_play and not paused and game.player.ui_blocked and game.region_id == "camp", "MVP did not start at camp with instructions")
	game.ui.close_modal()
	_check(not game.player.skill_manager.known_actions.has("fire_sigil"), "New game already knows fire sigil")
	var sm := game.player.skill_manager
	sm.equip_slot(0, sm.pool.get_skill("lightning_bolt"))
	_check(sm.get_slot(0) == null, "Unknown catalog spell is equippable")
	# Use the actual input -> player -> Interactable path for the first journey.
	for node in get_nodes_in_group("interactable"):
		if node is ExplorationInteractable and node.title == "进入监狱外院":
			game.player.global_position = node.global_position
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	await _frames()
	_check(game.region_id == "yard", "E input did not enter yard")
	await _interact("前往火药库")
	_check(game.region_id == "yard", "Locked forward exit was usable")
	await _interact("火阵铭刻记录")
	_check(not paused and game.player.ui_blocked and game.progress.spell_rules.has("fire_sigil_fireball") and sm.get_slot(4) != null, "Discovery did not teach and equip fire sigil")
	game.ui.close_modal()
	var count := game.progress.journal.size()
	await _interact("火阵铭刻记录")
	_check(game.progress.journal.size() == count, "Discovery granted twice")
	game.ui.close_modal()
	var before_attack := game.player.health_component.hp
	game.player.global_position = game.active_enemies[0].global_position + Vector2(-40, 0)
	await create_timer(game.active_enemies[0].attack_cooldown + game.active_enemies[0].melee_windup + 0.3).timeout
	_check(game.player.health_component.hp < before_attack, "Melee enemy AI did not attack the player")
	await _clear_encounter()
	await _interact("支路：军械档案")
	_check(game.region_id == "archive", "Optional branch exit missing")
	await _interact("震荡与焰环")
	game.ui.close_modal()
	_check(sm.known_actions.has("pulse") and sm.combinations.learned_rules.has("fire_sigil_pulse"), "Second recipe not learned")
	await _clear_encounter()
	await _travel("powder")
	await _clear_encounter()
	await _interact("支路：排水回廊")
	_check(game.region_id == "drain", "Frost branch missing")
	await _interact("寒霜铭刻记录")
	game.ui.close_modal()
	_check(sm.known_actions.has("frost_sigil"), "Frost sigil not learned")
	var pool_ui: SkillPoolUI = game.interface_root.get_node("SkillPoolUI")
	_check(pool_ui._combination_description(sm.pool.get_skill("frost_bolt")).contains("霜阵"), "Frost recipe UI shows the wrong field")
	_check(pool_ui._combination_description(sm.pool.get_skill("fire_sigil_burst")).contains("震荡"), "Burst recipe UI shows the wrong trigger")
	await _clear_encounter()

	# Execute two new data-driven recipes with real physics targets.
	game.player.global_position = Vector2(12000, 12000)
	game.player.mana_component.max_mp = 300
	game.player.mana_component.mp = 300
	game.player.mana_component.mp_regen_rate = 0
	var target := _target(Vector2(60, 0))
	var side := _target(Vector2(-60, 0))
	_check(sm.use_slot(4, game.player, Vector2.RIGHT), "Fire preparation did not start")
	await create_timer(0.9).timeout
	_check(sm.use_slot(0, game.player, Vector2.RIGHT), "Pulse combination did not start")
	await create_timer(0.6).timeout
	_check(target.hits == 1 and side.hits == 1, "Fire + pulse did not hit both sides")
	_check(game.player.mana_component.mp == 278, "Field/pulse cost incorrect")
	target.get_node("BuffManager").remove_status("burning")
	side.get_node("BuffManager").remove_status("burning")
	sm.combinations.clear_field() # Isolate the frost recipe; layered fields have their own integration test.
	_check(sm.use_slot(2, game.player, Vector2.RIGHT), "Frost preparation did not start")
	await create_timer(0.9).timeout
	_check(sm.combinations.field.field_type == "frost", "Frost field not placed")
	_check(sm.use_slot(5, game.player, Vector2.RIGHT), "Frost + spark did not start")
	await create_timer(0.6).timeout
	_check(target.hits == 2 and side.hits == 1 and target.move_speed < 100, "Frost projectile did not apply directional damage and slow")
	_check(game.player.mana_component.mp == 260, "Frost field/projectile cost incorrect")

	await _travel("gate")
	await _clear_encounter()
	await _interact("解锁营地捷径")
	_check(game.region_id == "camp", "Shortcut did not return to camp")
	await _interact("捷径：重卫关隘")
	_check(game.region_id == "gate" and game.active_enemies.is_empty(), "Shortcut/cleared region restore failed")
	await _interact("进入熔炉大厅")
	_check(game.region_id == "boss" and game.active_enemies[0] is Boss, "Boss encounter missing")
	await _clear_encounter()
	_check(game.progress.completed, "Boss death did not complete MVP")
	await _interact("完成探索，返回营地")
	_check(not paused and game.player.ui_blocked and is_instance_valid(game.ui.modal), "Completion screen missing")
	game.ui.close_modal()
	await _travel("camp")
	game.ui.show_journal()
	_check(not paused and game.player.ui_blocked and game.progress.journal.size() >= 3, "Journal missing discoveries")
	game.ui.close_modal()
	var original_intelligence := game.player.stats_component.intelligence
	game.player.stats_component.attribute_points = maxi(1, game.player.stats_component.attribute_points)
	await _interact("营地训练：分配属性")
	game._train("intelligence")
	_check(game.player.stats_component.intelligence == original_intelligence + 1, "Camp training did not apply attribute")
	game.ui.close_modal()
	sm.equip_hand("left", sm.pool.get_skill("pulse"))
	sm.unequip_slot(0)
	_check(SaveManager.instance.save_game(2), "Save failed")
	var restored := ExplorationProgress.new()
	restored.deserialize_save_data(SaveManager.instance.read_extension(2, MVPGame.SECTION))
	_check(restored.completed and restored.spell_rules.size() == 5 and restored.cleared.has("gate"), "Progress did not round-trip through disk")
	# Death must use expedition recovery, not the legacy HUD retry scene.
	game.player.health_component.invincible = false
	CombatExecutor.instance.reset_chain()
	CombatExecutor.report_hit(null, game.player, 5000, game.player.global_position)
	_check(game.player.health_component.is_dead and not paused and game.player.ui_blocked, "Death/recovery modal missing")
	_check(not game.get_node("HUDLayer")._death_active, "Legacy death screen hijacked MVP")
	game.ui.close_modal()
	await _travel("camp")
	_check(not game.player.health_component.is_dead and game.player.health_component.hp > 0, "Camp did not revive player")
	_check(game.progress.completed and game.progress.spell_rules.size() == 5, "Death discarded knowledge or milestones")
	# Recreate the entire scene and providers, restoring only persistent progress.
	game.queue_free()
	current_scene = null
	await _frames(5)
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(10)
	_check(game.progress.completed and game.progress.actions.has("frost_sigil") and game.region_id == "camp", "Fresh scene did not restore persistent progress")
	_check(game.player.skill_manager.left_hand != null and game.player.skill_manager.left_hand.data.get_id() == "pulse" and game.player.skill_manager.get_slot(0) == null, "Custom loadout or empty slots were not preserved")
	_check(game.player.stats_component.intelligence == original_intelligence + 1, "Trained attribute was not restored")
	game.ui.close_modal()
	await create_timer(0.6).timeout
	if errors.is_empty():
		print("Exploration MVP passed: input, discovery, three combinations, branches, boss, disk restore, death and fresh-scene restart")
	call_deferred("quit", 0 if errors.is_empty() else 1)
