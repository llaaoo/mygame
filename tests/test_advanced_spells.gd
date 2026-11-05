extends "res://tests/support/exploration_case.gd"

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(10)
	game.ui.close_modal()
	sm = game.player.skill_manager
	controller = sm.combinations
	supplies = controller.supplies
	await _interact("施法材料手册")
	game.ui.close_modal()
	await _travel("yard")
	await _interact("火阵铭刻记录")
	game.ui.close_modal()
	await _clear_encounter()
	await _travel("archive")
	await _interact("震荡与焰环")
	game.ui.close_modal()
	await _clear_encounter()
	await _travel("sanctum")
	await _interact("回响刻板")
	_check(not sm.known_actions.has("echo_mark"), "Guarded echo knowledge was available early")
	await _clear_encounter()
	await _interact("凝神碑")
	game.ui.close_modal()
	await _interact("回响刻板")
	game.ui.close_modal()
	_check(sm.known_actions.has("echo_mark") and supplies.count("echo_ink") == 5, "Echo lesson missing")
	await _travel("drain")
	await _interact("寒霜铭刻记录")
	game.ui.close_modal()
	await _clear_encounter()
	await _interact("毒理记录")
	game.ui.close_modal()
	await _travel("cistern")
	await _clear_encounter()
	await _interact("寒霜新星试验记录")
	game.ui.close_modal()
	await _interact("雷阵与导电实验记录")
	game.ui.close_modal()
	_check(game.progress.spell_rules.size() == 20, "All twenty authored spell combinations were not learned")
	await _travel("camp")
	for i in range(4):
		_check(supplies.craft("echo_ink"), "Echo ink crafting failed")
	_check(supplies.craft("venom_extract") and supplies.craft("ward_powder"), "Advanced material crafting failed")
	game.workshop.show_action(sm.pool.get_skill("ignite"))
	_check(paused, "Advanced material configuration did not open")
	game.ui.close_modal()

	# Isolated status conversion rollback; joint field activation has a dedicated test.
	await _arena()
	await _cast(3)
	var buffs: BuffManager = game.player.get_node("BuffManager")
	supplies.configure("ignite", "echo_ink")
	var preview := controller.preview(sm.get_slot(5).data, game.player)
	_check(preview.rule_id == "echo_spark" and preview.field == null and preview.cost == 15, "Status recipe priority/cost incorrect")
	var ink := supplies.count("echo_ink")
	var mana := game.player.mana_component.mp
	var original := sm.executor
	var reject := RejectingExecutor.new()
	sm.add_child(reject)
	sm.executor = reject
	await _cast(5)
	_check(buffs.has_buff("echo_ready") and supplies.count("echo_ink") == ink and game.player.mana_component.mp == mana, "Failed execution lost status/material/mana")
	sm.executor = original
	reject.queue_free()
	# Refreshing the same status ID creates a new preparation version.
	_check(sm.use_slot(5, game.player, Vector2.RIGHT), "Status refresh test did not start")
	buffs.apply_buff(sm.pool.get_skill("echo_mark").buff_resource.duplicate(true))
	await create_timer(0.4).timeout
	_check(controller.pending.is_empty() and supplies.count("echo_ink") == ink and game.player.mana_component.mp == mana, "Refreshed status committed an obsolete plan")
	await create_timer(0.35).timeout
	await _cast(5)
	_check(not buffs.has_buff("echo_ready") and supplies.count("echo_ink") == ink - 1, "Echo conversion did not consume exactly one status/material")
	_check(get_nodes_in_group("projectile").size() == 3, "Echo barrage did not create three projectiles")
	for projectile in get_nodes_in_group("projectile"):
		_check(projectile.get_meta("skill_data").projectile_pierce == 1, "Echo ink did not modify every projectile")
	_check(sm.pool.get_skill("echo_barrage").projectile_pierce == 0, "Echo ink changed the shared template")

	# Tick windows deduplicate Body/Hurtbox, and all pulses hit real health.
	await _arena()
	var target := _health_target(Vector2(60, 0))
	var wave := sm.pool.get_skill("echo_wave")
	var per_hit := sm.executor.resolve_damage(wave, CastContext.simple(game.player, Vector2.RIGHT, wave))
	await _cast(3)
	await _cast(0)
	await create_timer(0.9).timeout
	_check(target.calls == 3 and target.health.hp == 1000 - per_hit * 3, "Pulse windows duplicated colliders or invincibility swallowed pulses")
	# Main hit and reaction bonuses must be accepted together, then grant invincibility.
	var reactive := _health_target(Vector2(200, 200))
	var reactive_buffs: BuffManager = reactive.get_node("BuffManager")
	reactive_buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres").duplicate(true))
	reactive_buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres").duplicate(true))
	CombatExecutor.instance.reset_chain()
	var fireball := sm.pool.get_skill("fireball")
	CombatExecutor.report_hit(game.player, reactive, 100, reactive.position, fireball, fireball.tags)
	_check(reactive.health.hp == 765 and reactive.health.invincible, "Reaction bonuses/main damage did not total 235 on real health")
	CombatExecutor.report_hit(null, reactive, 100, reactive.position, null, ["test"])
	_check(reactive.health.hp == 765, "A separate follow-up hit bypassed invincibility")

	# A defensive conversion has a genuine damage multiplier and optional duration.
	await _arena()
	supplies.configure("focus", "ward_powder")
	var powder := supplies.count("ward_powder")
	await _cast(3)
	await _cast(1)
	_check(buffs.has_buff("resonant_guard") and supplies.count("ward_powder") == powder - 1, "Guard conversion/material missing")
	var snapshot := buffs.capture_status("resonant_guard")
	_check(snapshot.remaining > 11, "Ward powder did not extend shield duration")
	var hp := game.player.health_component.hp
	CombatExecutor.instance.reset_chain()
	CombatExecutor.report_hit(null, game.player, 20, game.player.position, null, ["test"])
	_check(game.player.health_component.hp == hp - 12, "Guard failed 40 percent damage reduction")
	paused = true
	var remaining: float = buffs.capture_status("resonant_guard").remaining
	await create_timer(0.2, true).timeout
	_check(is_equal_approx(buffs.capture_status("resonant_guard").remaining, remaining), "Pause advanced prepared guard")
	paused = false
	await create_timer(0.55).timeout
	await _cast(3)
	_check(controller.preview(sm.get_slot(0).data, game.player, true).rule_id == "guard_pulse", "Guard release did not outrank the concurrent echo mark")
	var left := _dummy(Vector2(-75, 0))
	var right := _dummy(Vector2(75, 0))
	await _empowered_cast(0)
	_check(not buffs.has_buff("resonant_guard") and buffs.has_buff("echo_ready") and left.damage_taken > 0 and right.damage_taken > 0, "Guard release consumed the wrong preparation or missed either side")
	hp = game.player.health_component.hp
	CombatExecutor.report_hit(null, game.player, 20, game.player.position, null, ["test"])
	_check(game.player.health_component.hp == hp - 20, "Released guard retained damage reduction")

	await _arena()
	await _cast(3)
	sm.equip_slot(3, sm.pool.get_skill("water_call"))
	game.player.health_component.hp -= 30
	hp = game.player.health_component.hp
	await _cast(3)
	await create_timer(4.5).timeout
	_check(game.player.health_component.hp == hp + 24 and not buffs.has_buff("restoring_echo"), "Restoring echo did not heal exactly four ticks and expire")

	await _arena()
	sm.equip_slot(4, sm.pool.get_skill("venom_mist"))
	var venom := supplies.count("venom_extract")
	var first := _dummy(Vector2(130, 0))
	var second := _dummy(Vector2(220, 0))
	await _cast(3)
	await _cast(4)
	_check(first.damage_taken > 0 and second.damage_taken > 0 and first.get_node("BuffManager").has_buff("poison") and supplies.count("venom_extract") == venom - 1 and not buffs.has_buff("echo_ready"), "Echo venom failed penetration, poison or one-time costs")
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	_check(surfaces.get_surface(_cell(first.position)).get("state") == "poisoned", "Spore impact did not create toxic terrain")
	await _arena()
	sm.equip_slot(4, sm.pool.get_skill("venom_mist"))
	var washed := _dummy(Vector2(120, 0))
	await _cast(4)
	_check(washed.get_node("BuffManager").has_buff("poison"), "Base venom mist did not poison")
	sm.equip_slot(3, sm.pool.get_skill("water_call"))
	await _cast(3)
	_check(not washed.get_node("BuffManager").has_buff("poison") and surfaces.get_surface(_cell(washed.position)).get("state") == "wet", "Water did not cleanse target and toxic terrain")
	await _arena()
	supplies.configure("ignite", "venom_extract")
	var mixed := _dummy(Vector2(110, 0))
	await _cast(2)
	await _cast(5)
	_check(mixed.get_node("BuffManager").has_buff("frozen") and mixed.get_node("BuffManager").has_buff("poison"), "Venom material did not add poison to frost")
	supplies.configure("ignite", "")
	controller.clear_field() # Isolate the fire follow-up; joint casting is covered separately.
	await _cast(4)
	await _cast(5)
	_check(not mixed.get_node("BuffManager").has_buff("frozen") and not mixed.get_node("BuffManager").has_buff("poison"), "Fire failed the mixed freeze/poison follow-up")

	await _arena()
	await _cast(3)
	var short_mark := sm.pool.get_skill("echo_mark").buff_resource.duplicate(true) as Buff
	short_mark.duration = 0.1
	buffs.apply_buff(short_mark)
	mana = game.player.mana_component.mp
	_check(sm.use_slot(5, game.player, Vector2.RIGHT), "Expiring status test did not start")
	await create_timer(0.5).timeout
	_check(controller.pending.is_empty() and game.player.mana_component.mp == mana and not buffs.has_buff("echo_ready"), "Expired preparation consumed mana or downgraded to a basic action")

	# The additional world locks consume real spell hits in their authored order.
	await _travel("sanctum")
	var puzzle := _puzzle("magic.triad_lock")
	game.player.position = puzzle.position - Vector2(0, 70)
	await _hit_puzzle("frost_ring", puzzle)
	await _hit_puzzle("fire_sigil_burst", puzzle)
	_check(not puzzle.completed and puzzle._steps[0] == 2, "Three-stage lock completed without echo")
	await create_timer(sm.get_cooldown("slot_3") + 0.1).timeout
	await _cast(3)
	await _cast(5, Vector2.DOWN)
	_check(puzzle.completed and game.progress.claims.has(puzzle.spec.id), "Echo failed final world-lock stage")
	await _travel("gate")
	await _clear_encounter()
	puzzle = _puzzle("magic.guard_oath")
	game.player.position = puzzle.position - Vector2(0, 50)
	await create_timer(sm.get_cooldown("slot_3") + 0.1).timeout
	await _cast(3)
	await _cast(1)
	await _empowered_cast(0)
	_check(puzzle.completed and game.progress.claims.has(puzzle.spec.id), "Guard release did not activate oath stone")
	await _travel("drain")
	puzzle = _puzzle("magic.toxic_still")
	game.player.position = puzzle.position - Vector2(0, 80)
	sm.equip_slot(3, sm.pool.get_skill("venom_mist"))
	await _cast(3, Vector2.DOWN)
	await _hit_puzzle("fire_sigil_burst", puzzle)
	_check(puzzle.completed and game.progress.claims.has(puzzle.spec.id), "Poison/fire failed distillation lock")
	await _arena()
	await _cast(3)
	var saved := supplies.serialize()
	_check(SaveManager.instance.save_game(2), "Advanced progress save failed")
	game.queue_free()
	current_scene = null
	await _frames(5)
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(10)
	game.ui.close_modal()
	_check(game.progress.spell_rules.size() == 20 and game.player.skill_manager.combinations.supplies.serialize() == saved and game.progress.claims.has("magic.guard_oath") and game.progress.claims.has("magic.triad_lock") and game.progress.claims.has("magic.toxic_still"), "Advanced knowledge, materials or lock rewards failed disk restore")
	_check(not game.player.get_node("BuffManager").has_buff("echo_ready"), "Temporary preparation was restored as permanent progress")
	game.queue_free()
	current_scene = null
	await _frames(5)
	if errors.is_empty():
		print("Advanced spells passed: 15 recipes, prepared-state transactions, real-health reactions/guard, pulse windows, regeneration, poison, crafting, three locks and persistence")
	call_deferred("quit", 0 if errors.is_empty() else 1)
