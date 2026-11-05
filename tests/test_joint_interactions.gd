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
	await _clear_encounter()
	await _interact("凝神碑")
	game.ui.close_modal()
	await _interact("回响刻板")
	game.ui.close_modal()
	await _travel("drain")
	await _clear_encounter()
	await _interact("寒霜铭刻记录")
	game.ui.close_modal()
	await _interact("毒理记录")
	game.ui.close_modal()
	await _travel("cistern")
	await _clear_encounter()
	await _interact("寒霜新星试验记录")
	game.ui.close_modal()
	await _interact("雷阵与导电实验记录")
	game.ui.close_modal()
	_check(controller.rules.size() == game.catalog.chapter.spell_rules.size() and supplies.catalog.size() == 7, "Registered spell rules or retained material catalog diverged")

	# Existing fields cooperate; one input pays the complete, visible result.
	await _arena()
	var fire := await _place("fire")
	var storm := await _place("storm")
	var preview := controller.preview(sm.pool.get_skill("ignite"), game.player)
	_check(controller.live_fields().size() == 2 and preview.components.size() == 2 and preview.cost == 23 and preview.effect_label.contains("火球") and preview.effect_label.contains("雷矢"), "Overlapping field preview did not include both effects/costs")
	await _cast(5)
	_check(fire.charges == 1 and storm.charges == 1 and game.player.mana_component.mp == 260 and get_nodes_in_group("projectile").size() == 2, "Joint spark did not consume one charge per field and emit both projectiles")
	var fire_id := fire.get_instance_id()
	var storm_id := storm.get_instance_id()
	storm = await _place("storm")
	_check(controller.live_fields().size() == 2 and fire.get_instance_id() == fire_id and fire.charges == 1 and storm.get_instance_id() != storm_id and storm.charges == 2, "Replacing one field erased another type or reused its charges")

	# Walking out of only one circle during preparation cancels the entire action.
	await _arena()
	var center := game.player.position
	game.player.position = center + Vector2(-40, 0)
	fire = await _place("fire")
	game.player.position = center + Vector2(40, 0)
	storm = await _place("storm")
	game.player.mana_component.mp = 22
	_check(not sm.use_slot(5, game.player, Vector2.RIGHT) and fire.charges == 2 and storm.charges == 2, "Insufficient combined mana silently released a subset")
	game.player.mana_component.mp = 300
	_check(sm.use_slot(5, game.player, Vector2.RIGHT), "Spatial revalidation test did not start")
	game.player.position = center + Vector2(120, 0)
	await create_timer(0.4).timeout
	_check(controller.pending.is_empty() and game.player.mana_component.mp == 300 and fire.charges == 2 and storm.charges == 2 and get_nodes_in_group("projectile").is_empty(), "Leaving one field committed a partial action")
	game.player.position = center + Vector2(40, 0)
	await create_timer(0.35).timeout
	_check(sm.use_slot(5, game.player, Vector2.RIGHT), "Expiry revalidation test did not start")
	fire.expire()
	await create_timer(0.4).timeout
	_check(game.player.mana_component.mp == 300 and storm.charges == 2 and get_nodes_in_group("projectile").is_empty(), "Expired field committed the remaining effect")

	# An already staged first effect cannot escape if the next one is rejected.
	await _arena()
	fire = await _place("fire")
	var frost := await _place("frost")
	await _cast(3)
	supplies.configure("ignite", "echo_ink")
	var ink := supplies.count("echo_ink")
	var mana := game.player.mana_component.mp
	preview = controller.preview(sm.pool.get_skill("ignite"), game.player)
	_check(preview.components.size() == 3 and preview.cost == 37 and preview.material_costs == {"echo_ink": 1}, "Field/status/material composition duplicated costs or lost a component")
	var emitted: Array[String] = []
	var on_cast := func(event: CombatEvent): emitted.append(event.skill.get_id())
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_CAST, on_cast)
	var original := sm.executor
	var reject := RejectSecond.new()
	sm.add_child(reject)
	sm.executor = reject
	await _cast(5)
	var buffs: BuffManager = game.player.get_node("BuffManager")
	_check(emitted.is_empty() and get_nodes_in_group("projectile").is_empty() and game.player.mana_component.mp == mana and supplies.count("echo_ink") == ink and fire.charges == 2 and frost.charges == 2 and buffs.has_buff("echo_ready"), "Partial execution leaked an effect/event or failed to refund all resources")
	sm.executor = original
	reject.queue_free()
	await _cast(5)
	_check(emitted.size() == 3 and get_nodes_in_group("projectile").size() == 5 and fire.charges == 1 and frost.charges == 1 and not buffs.has_buff("echo_ready") and supplies.count("echo_ink") == ink - 1 and game.player.mana_component.mp == mana - 37, "Successful field/status composition lost or double-consumed a component")
	CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_CAST, on_cast)

	# Both fields' AoEs damage real health within the same invincibility window.
	await _arena()
	await _place("fire")
	await _place("frost")
	var target := _health_target(Vector2(60, 0))
	target.health.invincible_duration = 2.0 # Keep the asynchronous assertion inside an explicit window.
	var expected := 0
	for id in ["fire_sigil_burst", "frost_ring"]:
		var skill := sm.pool.get_skill(id)
		expected += sm.executor.resolve_damage(skill, CastContext.simple(game.player, Vector2.RIGHT, skill))
	await _cast(0)
	var fire_damage := sm.executor.resolve_damage(sm.pool.get_skill("fire_sigil_burst"), CastContext.simple(game.player, Vector2.RIGHT, sm.pool.get_skill("fire_sigil_burst")))
	var frost_damage := sm.executor.resolve_damage(sm.pool.get_skill("frost_ring"), CastContext.simple(game.player, Vector2.RIGHT, sm.pool.get_skill("frost_ring")))
	var valid_totals := [expected + int(round(frost_damage * 0.5)), expected + int(round(fire_damage * 0.6))]
	_check(1000 - target.health.hp in valid_totals and target.calls == 3, "Same-action field effects lost a primary hit, doubled a contact or failed the shared steam/melt reaction")
	var hp := target.health.hp
	CombatExecutor.report_hit(null, target, 20, target.position, null, ["separate_action"])
	_check(target.health.hp == hp, "Unrelated action bypassed shared-action invincibility")

	# Mutually exclusive boons still select one result and only pay for that result.
	await _arena()
	fire = await _place("fire")
	frost = await _place("frost")
	preview = controller.preview(sm.pool.get_skill("focus"), game.player)
	_check(preview.components.size() == 1 and preview.skill.get_id() == "frost_stride" and preview.cost == 10, "Exclusive field boons wasted resources on overwritten buffs")
	await _cast(1)
	_check(fire.charges == 2 and frost.charges == 1 and buffs.has_buff("frost_stride") and not buffs.has_buff("ember_focus"), "Exclusive boon consumed the wrong field")
	await _arena()
	fire = await _place("fire")
	await _cast(3)
	await _cast(1)
	_check(buffs.has_buff("resonant_guard") and fire.charges == 2, "Prepared guard did not win its exclusive buff group")

	# The existing offensive boon turns an ordinary physical swing into an elemental tool.
	await _arena()
	var base_attack := game.player.combat_component.attack_damage
	await _place("fire")
	await _cast(1)
	_check("fire" in buffs.get_attack_tags(), "Ember boon did not imbue melee")
	target = _health_target(Vector2(40, 0))
	var target_buffs: BuffManager = target.get_node("BuffManager")
	target_buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres").duplicate(true))
	target_buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres").duplicate(true))
	var melee := game.player.combat_component.attack_damage
	var attack_costs := supplies.serialize()
	game.player.combat_component.perform_melee_attack(Vector2.RIGHT)
	await create_timer(0.22).timeout
	expected = melee + int(round(melee * 0.6)) + int(round(melee * 0.75))
	_check(target.health.hp == 1000 - expected and target.calls == 3 and target_buffs.has_buff("burning") and not target_buffs.has_buff("frozen") and not target_buffs.has_buff("poison"), "Imbued physical swing failed reactions or duplicated hitbox contacts")
	_check(supplies.serialize() == attack_costs, "Melee re-consumed spell materials")
	target.queue_free()
	await _frames()
	var barrel := load("res://world/object/oil_barrel.tscn").instantiate() as MapObject
	barrel.position = game.player.position + Vector2(40, 0)
	game.region_root.add_child(barrel)
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	surfaces.force_set_surface(_cell(barrel.position), "oiled", 10, "fixture")
	game.player.combat_component.perform_melee_attack(Vector2.RIGHT)
	await create_timer(0.22).timeout
	_check(surfaces.get_surface(_cell(barrel.position)).get("state") == "burning", "Imbued melee failed to ignite world oil")
	buffs.clear_all()
	_check(buffs.get_attack_tags().is_empty() and game.player.combat_component.attack_damage == base_attack, "Expired/removed boon left a permanent melee element")

	# Charge travels through water connectivity, including corners, and stops at dry gaps.
	await _arena()
	await _place("storm")
	var origin := _cell(game.player.position + Vector2(120, 0))
	var route: Array[Vector2i] = [origin, origin + Vector2i(1, 0), origin + Vector2i(2, 0), origin + Vector2i(2, 1)]
	for cell in route:
		surfaces.force_set_surface(cell, "wet", 12, "fixture")
	var isolated := origin + Vector2i(0, 2)
	surfaces.force_set_surface(isolated, "wet", 12, "fixture")
	var endpoint: Vector2i = route.back()
	var connected_target := _health_target(Vector2(endpoint.x * 64 + 32, endpoint.y * 64 + 32) - game.player.position)
	connected_target.add_to_group("enemy")
	var isolated_target := _health_target(Vector2(isolated.x * 64 + 32, isolated.y * 64 + 32) - game.player.position)
	isolated_target.add_to_group("enemy")
	await _cast(5)
	await create_timer(1.2).timeout
	for cell in route:
		_check(surfaces.get_surface(cell).get("state") == "electrified", "Lightning failed to conduct around a connected corner")
	_check(surfaces.get_surface(isolated).get("state") == "wet" and connected_target.health.hp < 1000 and isolated_target.health.hp == 1000, "Conduction crossed dry ground or failed its actual status damage")
	var long_origin := Vector2i(300, 300)
	for i in range(60):
		surfaces.force_set_surface(long_origin + Vector2i(i, 0), "wet", 10, "bounded_fixture")
	surfaces.apply_tags(long_origin, ["lightning"], "bounded_test")
	var charged := 0
	for i in range(60):
		charged += int(surfaces.get_surface(long_origin + Vector2i(i, 0)).get("state") == "electrified")
	_check(charged == 48, "Connected reaction escaped its bounded work budget")

	# The same existing fire interaction opens the existing cache through an imbued swing.
	await _travel("yard")
	var puzzle := _puzzle("magic.bramble_cache")
	game.player.position = puzzle.position - Vector2(40, 0)
	buffs.apply_buff(sm.pool.get_skill("ember_focus").buff_resource.duplicate(true))
	game.player.combat_component.perform_melee_attack(Vector2.RIGHT)
	await create_timer(0.22).timeout
	_check(puzzle.completed and game.progress.claims.has(puzzle.spec.id), "World cache rejected an existing element delivered through melee")
	await _travel("camp")
	_check(controller.live_fields().is_empty() and buffs.get_attack_tags().is_empty(), "Region cleanup retained fields or elemental melee")
	game.queue_free()
	current_scene = null
	await _frames(5)
	if errors.is_empty():
		print("Joint interactions passed: existing field composition, atomic staged casts, real-health families, elemental melee/world reuse and connected-water conduction; registered content stays consistent")
	call_deferred("quit", 0 if errors.is_empty() else 1)
