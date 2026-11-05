extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func run() -> void:
	var results: Array[Dictionary] = []
	for guarded in [false, true]:
		var fixture := Fixture.new(self)
		var game := await fixture.boot()
		game.progress.choices.waterworks_choice = "cooling"
		game._change_region("boss")
		var player := game.player
		var boss := game.active_enemies[0]
		boss.rewards_enabled = false # Remove post-kill RNG; live AI and damage are unchanged.
		var sm := player.skill_manager
		sm.restrict_actions = false
		sm.combinations.learned_rules.echo_focus = true
		sm.combinations.supplies.grant({"echo_ink": 1})
		player.health_component.regen_rate = 0
		player.mana_component.mp_regen_rate = 0
		check(player.health_component.max_hp == 100 and player.mana_component.max_mp == 60 and boss.health_component.max_hp == 210, "Balance sample changed authored caps")
		if guarded:
			sm.equip_slot(0, sm.pool.get_skill("echo_mark"))
			sm.equip_slot(1, sm.pool.get_skill("focus"))
			check(sm.use_slot(0, player, Vector2.RIGHT), "Echo preparation failed")
			await create_timer(.5).timeout
			check(sm.use_slot(1, player, Vector2.RIGHT), "Guard preparation failed")
			await create_timer(.4).timeout
			check((player.get_node("BuffManager") as BuffManager).has_buff("resonant_guard"), "Guard did not actually activate")
		player.position = Vector2(0, -30)
		boss.position = Vector2(48, -30)
		var started := Time.get_ticks_msec()
		var swings := 0
		while is_instance_valid(boss) and not player.health_component.is_dead and Time.get_ticks_msec() - started < 14000:
			player.combat_component.perform_melee_attack(player.global_position.direction_to(boss.global_position))
			swings += 1
			await create_timer(.65).timeout
		var result := {"guarded": guarded, "seconds": (Time.get_ticks_msec() - started) / 1000.0, "swings": swings, "hp": player.health_component.hp, "mp": player.mana_component.mp, "boss_hp": boss.health_component.hp if is_instance_valid(boss) else 0, "dead": player.health_component.is_dead}
		results.append(result)
		print("Live AI timed melee sample: " + JSON.stringify(result))
		check(player.combat_component.attack_damage == 18, "Balance sample did not use new melee damage")
		await fixture.close()
	check(results[0].dead and results[0].boss_hp > 0, "Cooled boss still loses to stationary unprepared timed melee")
	check(not results[1].dead and results[1].boss_hp == 0 and results[1].mp == 44, "Retaining defensive preparation did not create a viable alternative")
	if errors.is_empty(): print("Tactical balance passed: 100HP/60MP, unchanged 210HP cooled boss and live AI; timed melee loses without preparation, retained guard succeeds")
	quit(0 if errors.is_empty() else 1)
