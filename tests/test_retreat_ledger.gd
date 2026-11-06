extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func run() -> void:
	var fixture := Fixture.new(self)
	var game := await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	game._change_region("yard")
	for enemy in game.active_enemies: enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var p := game.player
	p.position = Vector2(-300, -200)
	p.health_component.hp = 50
	p.mana_component.mp = 20
	var stock := p.skill_manager.combinations.supplies.serialize()
	check(game.trial_recorder.start("冻结控制"), "Ledger failed to start")
	game.ui.show_pause()
	game.ui.retreat_requested.emit()
	check(not paused and not p.ui_blocked and p.field_work.is_busy() and game.region_id == "yard", "Menu retreat paused or teleported immediately")
	p.field_work.tick(2.99)
	check(game.region_id == "yard", "Retreat finished early")
	p.health_component.invincible = false
	CombatExecutor.report_hit(null, p, 2, p.position, null, ["test"])
	check(not p.field_work.is_busy() and game.region_id == "yard" and stock == p.skill_manager.combinations.supplies.serialize(), "Interrupted retreat travelled or charged resources")
	game.retreat.begin()
	p.field_work.tick(3)
	for i in range(6): await process_frame
	check(game.region_id == "camp" and p.health_component.hp == 48 and p.mana_component.mp == 20, "Retreat healed/refilled vitals")
	p.health_component.heal(100, "skill")
	p.mana_component.restore_mp(100, "drop")
	p.health_component.heal(100, "skill")
	p.mana_component.restore_mp(100, "drop")
	check(game.trial_recorder.run.recovery.hp.skill == 52 and game.trial_recorder.run.recovery.mp.drop == 40, "Ledger counted overflow or duplicate recovery")
	p.mana_component.mp = 50
	p.mana_component.begin_transaction()
	p.mana_component.restore_mp(5, "skill")
	p.mana_component.finish_transaction(false)
	check(not game.trial_recorder.run.recovery.mp.has("skill") and p.mana_component.mp == 50, "Rejected transaction leaked recovery receipts")
	p.health_component.hp = 99
	p.health_component.regen_rate = 1
	p.health_component.regen_bonus = 1
	p.health_component.regen_bonus_sources = {"food": 1.0}
	p.health_component.regen_delay = 0
	p.health_component.tick(10)
	check(is_equal_approx(game.trial_recorder.run.recovery.hp.natural, .5) and is_equal_approx(game.trial_recorder.run.recovery.hp.food, .5), "Regeneration shares exceeded actual available health")
	var report := game.trial_recorder.finish("撤离与实际回复检查")
	check(report.work_attempts.retreat == 2 and report.work_interruptions.retreat == 1 and report.work_actions == 1, "Retreat attempt/interrupt counters incorrect")
	check(game.progress.validate_save_data(game.progress.serialize_save_data()), "New ledger shape cannot save")
	check(not game.retreat.reason().is_empty(), "Camp allowed redundant retreat")
	await fixture.close()
	if errors.is_empty(): print("Retreat ledger passed: live menu transition, duration/damage, no charge/refill, actual/clamped recovery, transaction rollback, source shares and compatible persistence")
	quit(0 if errors.is_empty() else 1)
