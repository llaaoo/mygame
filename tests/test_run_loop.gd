extends SceneTree


func _init() -> void:
	var packed := load("res://main.tscn") as PackedScene
	if not packed:
		push_error("main.tscn failed to load")
		quit(1)
		return

	var game := packed.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame

	var run_manager := game.get_node_or_null("RunManager") as RunManager
	if not run_manager:
		push_error("RunManager missing")
		quit(1)
		return
	run_manager.persist_meta = false

	if run_manager.state.status != RunState.Status.RUNNING:
		push_error("Run did not start")
		quit(1)
		return

	run_manager._toggle_pause()
	if not paused or not run_manager._pause_panel:
		push_error("Pause overlay did not open")
		quit(1)
		return
	run_manager._toggle_pause()
	if paused or run_manager._pause_panel:
		push_error("Pause overlay did not close")
		quit(1)
		return

	for i in range(RunManager.NORMAL_ROOM_COUNT):
		run_manager._alive_enemies.clear()
		run_manager._check_room_clear()
		await process_frame
		run_manager._on_exit_body_entered(run_manager._player)
		await process_frame
		if run_manager.state.status != RunState.Status.REWARD:
			push_error("Room %d did not enter reward state" % (i + 1))
			quit(1)
			return
		var choices: Array[Dictionary] = run_manager.state.active_reward_choices
		if choices.is_empty():
			push_error("Room %d produced no rewards" % (i + 1))
			quit(1)
			return
		run_manager._on_reward_selected(choices[0])
		await process_frame

	if run_manager.state.status != RunState.Status.BOSS:
		push_error("Boss room did not start")
		quit(1)
		return
	if not run_manager._room_root.get_node_or_null("RunBoss_FireLord"):
		push_error("Boss room did not instantiate Fire Lord")
		quit(1)
		return

	run_manager._apply_relic("firebrand")
	if not run_manager.state.relic_ids.has("firebrand"):
		push_error("Relic was not recorded")
		quit(1)
		return
	if run_manager._player.skill_manager.executor.modifiers_by_stage[DamageModifier.Stage.MULTIPLY].is_empty():
		push_error("Relic did not register a damage modifier")
		quit(1)
		return

	run_manager._alive_enemies.clear()
	run_manager._check_room_clear()
	await process_frame
	run_manager._on_exit_body_entered(run_manager._player)
	await process_frame
	if run_manager.state.status != RunState.Status.CLEARED:
		push_error("Run did not clear after boss")
		quit(1)
		return

	print("Run loop smoke test passed")
	quit(0)
