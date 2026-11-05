extends "res://tests/support/exploration_case.gd"

func _context(slot: int, empower: bool) -> CastContext:
	var context := CastContext.simple(game.player, Vector2.RIGHT, sm.get_slot(slot).data)
	context.empower = empower
	return context

func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.shift_pressed = pressed
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

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
	for stop in [["yard", ["火阵铭刻记录"]], ["archive", ["震荡与焰环"]], ["sanctum", ["凝神碑", "回响刻板"]], ["drain", ["寒霜铭刻记录", "毒理记录"]], ["cistern", ["寒霜新星试验记录", "雷阵与导电实验记录"]]]:
		await _travel(stop[0])
		await _clear_encounter()
		for title in stop[1]:
			await _interact(title)
			game.ui.close_modal()
	var buffs: BuffManager = game.player.get_node("BuffManager")
	_check(controller.rules.size() == game.catalog.chapter.spell_rules.size() and supplies.catalog.size() == 7, "Registered spell rules or retained material catalog diverged")

	# Keeping the boon increases compatible spell damage without spending the boon.
	await _arena()
	var base_attack := game.player.combat_component.attack_damage
	await _place("fire")
	await _cast(1)
	var preview := controller.preview(sm.pool.get_skill("ignite"), game.player)
	var base := sm.pool.get_skill("fireball")
	_check(preview.cost == 12 and preview.skill.damage == int(round(base.damage * 1.2)) and preview.retained_boons.has("余烬战意") and preview.consumed_boons.is_empty(), "Retained fire boon damage/cost/preview incorrect")
	var target := _health_target(Vector2(140, 0))
	var damage := sm.executor.resolve_damage(preview.skill, CastContext.simple(game.player, Vector2.RIGHT, preview.skill))
	await _cast(5)
	_check(target.health.hp == 1000 - damage and buffs.has_buff("ember_focus") and game.player.combat_component.attack_damage == base_attack + 8, "Ordinary spell lost its retained boon or passive damage")
	# A depleted circle cannot turn the mobile boon into a free direct fireball.
	preview = controller.preview(sm.pool.get_skill("ignite"), game.player, true)
	_check(preview.skill.get_id() == "ignite" and preview.cost == 7 and preview.skill.aoe_visual.radius == 64 and preview.skill.creates_surface == "burning" and preview.consumed_boons.has("余烬战意"), "Released ember did not preserve the basic action while changing its shape")
	await create_timer(sm.get_cooldown("slot_5") + 0.05).timeout
	var close := _health_target(Vector2(40, 0))
	damage = sm.executor.resolve_damage(preview.skill, CastContext.simple(game.player, Vector2.RIGHT, preview.skill))
	# Actual Shift input is sampled once; releasing it during preparation keeps intent.
	_shift(true)
	_check(Input.is_key_pressed(KEY_SHIFT) and sm.use_slot(5, game.player, Vector2.RIGHT), "Shift input did not request boon expenditure")
	_check(controller.pending.empower, "Release intent was not captured")
	_shift(false)
	await create_timer(0.7).timeout
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	_check(close.health.hp == 1000 - damage and not buffs.has_buff("ember_focus") and game.player.combat_component.attack_damage == base_attack and buffs.get_attack_tags().is_empty(), "Released ember did not trade ongoing melee/spell benefits for the committed attack")
	_check(surfaces.get_surface(_cell(close.position)).get("state") == "burning", "Released ember failed its world effect")
	_check(sm.pool.get_skill("ignite").aoe_visual.radius == 28 and sm.pool.get_skill("ignite").creates_surface.is_empty(), "Boon release mutated the action template")

	# Incompatible casts retain the boon; compatible release stacks with material shape.
	await _arena()
	var speed := game.player.move_speed
	await _place("frost")
	await _cast(1)
	sm.equip_slot(4, sm.pool.get_skill("venom_mist"))
	preview = controller.preview(sm.pool.get_skill("venom_mist"), game.player, true)
	_check(preview.cost == 6 and preview.consumed_boons.is_empty(), "Incompatible spell spent or charged the frost boon")
	await _empowered_cast(4, Vector2.LEFT)
	_check(buffs.has_buff("frost_stride") and is_equal_approx(game.player.move_speed, speed * 1.3), "Incompatible spell removed mobility")
	supplies.configure("ignite", "frost_salt")
	var salt := supplies.count("frost_salt")
	preview = controller.preview(sm.pool.get_skill("ignite"), game.player, true)
	_check(preview.cost == 15 and preview.skill.projectile_pierce == 3 and preview.skill.damage == int(round(sm.pool.get_skill("frost_bolt").damage * 1.6)), "Frost release/material modifiers compounded incorrectly")
	var targets: Array[HealthTarget] = []
	for x in [100, 150, 200, 250]:
		targets.append(_health_target(Vector2(x, 0)))
	damage = sm.executor.resolve_damage(preview.skill, CastContext.simple(game.player, Vector2.RIGHT, preview.skill))
	await _empowered_cast(5)
	for victim in targets:
		_check(victim.health.hp == 1000 - damage, "Frost release did not pierce four real targets exactly once")
	_check(not buffs.has_buff("frost_stride") and is_equal_approx(game.player.move_speed, speed) and supplies.count("frost_salt") == salt - 1, "Frost release retained mobility or duplicated material costs")
	_check(sm.pool.get_skill("frost_bolt").projectile_pierce == 0, "Frost release changed the shared projectile")

	# Static focus keeps its existing on-hit bonus; discharge replaces that benefit.
	await _arena()
	supplies.configure("focus", "ward_powder")
	await _place("storm")
	await _cast(1)
	target = _health_target(Vector2(120, 0))
	preview = controller.preview(sm.pool.get_skill("ignite"), game.player)
	base = sm.pool.get_skill("storm_bolt")
	damage = sm.executor.resolve_damage(base, CastContext.simple(game.player, Vector2.RIGHT, base))
	await _cast(5)
	_check(target.health.hp == 1000 - damage - int(round(damage * 0.35)) and buffs.has_buff("static_focus"), "Retained static focus lost its on-hit bonus or was consumed")
	await _place("storm")
	target.position = game.player.position + Vector2(260, 0)
	supplies.configure("ignite", "storm_dust")
	var dust := supplies.count("storm_dust")
	preview = controller.preview(sm.pool.get_skill("ignite"), game.player, true)
	_check(preview.cost == 18 and preview.skill.projectile_count == 5 and preview.consumed_boons.has("雷息"), "Static discharge wasted overlapping scatter material or duplicated boon surcharge")
	var hp := target.health.hp
	damage = sm.executor.resolve_damage(preview.skill, CastContext.simple(game.player, Vector2.RIGHT, preview.skill))
	await _empowered_cast(5)
	_check(target.health.hp == hp - damage and get_nodes_in_group("projectile").size() == 4 and not buffs.has_buff("static_focus") and supplies.count("storm_dust") == dust - 1, "Static discharge damage/scatter/cost was incorrect or kept the old on-hit bonus")

	# The shield is a deliberate resource, not an automatic replacement of every pulse.
	await _arena()
	await _cast(3)
	await _cast(1)
	controller.clear_field()
	_check(buffs.has_buff("resonant_guard"), "Guard setup failed")
	preview = controller.preview(sm.pool.get_skill("pulse"), game.player)
	_check(preview.skill.get_id() == "pulse" and preview.cost == 3 and preview.consumed_boons.is_empty(), "Ordinary pulse automatically sacrificed defense")
	await _cast(0)
	_check(buffs.has_buff("resonant_guard"), "Ordinary pulse consumed guard")
	await create_timer(sm.get_cooldown("slot_0") + 0.05).timeout
	var left := _health_target(Vector2(-70, 0))
	var right := _health_target(Vector2(70, 0))
	preview = controller.preview(sm.pool.get_skill("pulse"), game.player, true)
	_check(preview.skill.get_id() == "guard_release" and preview.cost == 8 and preview.consumed_boons.has("共鸣护盾"), "Guard release intent/preview incorrect")
	await _empowered_cast(0)
	_check(not buffs.has_buff("resonant_guard") and left.health.hp < 1000 and right.health.hp < 1000, "Explicit guard sacrifice failed")

	# A late rejection restores the exact boon, ongoing stats and every other cost.
	await _arena()
	var fire := await _place("fire")
	await _cast(1)
	var frost := await _place("frost")
	supplies.configure("ignite", "resin")
	var resin := supplies.count("resin")
	var mana := game.player.mana_component.mp
	var before: float = buffs.capture_status("ember_focus").remaining
	preview = controller.preview(sm.pool.get_skill("ignite"), game.player, true)
	_check(preview.cost == 29 and preview.components.size() == 2 and preview.components[0].skill.surface_duration == 6, "Joint boon/material release lost the longer resin effect or charged the boon twice")
	var original := sm.executor
	var reject := RejectSecond.new()
	sm.add_child(reject)
	sm.executor = reject
	await _empowered_cast(5)
	_check(buffs.has_buff("ember_focus") and game.player.combat_component.attack_damage == base_attack + 8 and "fire" in buffs.get_attack_tags() and game.player.mana_component.mp == mana and supplies.count("resin") == resin and fire.charges == 1 and frost.charges == 2 and get_nodes_in_group("projectile").is_empty(), "Rejected release failed to restore ongoing boon effects and all costs")
	var after: float = buffs.capture_status("ember_focus").remaining
	_check(after <= before and after > before - 1, "Rejected release refreshed or lost the boon's remaining lifetime")
	sm.executor = original
	reject.queue_free()
	await _empowered_cast(5)
	_check(not buffs.has_buff("ember_focus") and game.player.combat_component.attack_damage == base_attack and game.player.mana_component.mp == mana - 29 and supplies.count("resin") == resin - 1 and frost.charges == 1, "Accepted joint release left passive effects or miscounted costs")

	# Both released and retained boon plans revalidate expiry/removal before committing.
	await _arena()
	fire = await _place("fire")
	await _cast(1)
	mana = game.player.mana_component.mp
	_check(sm.use_slot_with_context(5, game.player, _context(5, true)), "Boon removal test failed to start")
	buffs.remove_status("ember_focus")
	await create_timer(0.4).timeout
	_check(controller.pending.is_empty() and game.player.mana_component.mp == mana and fire.charges == 1 and get_nodes_in_group("projectile").is_empty(), "Removed boon degraded to a basic cast or consumed resources")
	await _arena()
	frost = await _place("frost")
	await _cast(1)
	var expiring := sm.pool.get_skill("frost_stride").buff_resource.duplicate(true) as Buff
	expiring.duration = 0.1
	buffs.apply_buff(expiring)
	mana = game.player.mana_component.mp
	_check(sm.use_slot(5, game.player, Vector2.RIGHT), "Passive expiry test failed to start")
	await create_timer(0.4).timeout
	_check(controller.pending.is_empty() and game.player.mana_component.mp == mana and frost.charges == 1 and not buffs.has_buff("frost_stride"), "Expired passive boon silently changed the accepted plan")
	await _travel("camp")
	_check(buffs.get_spell_boons().is_empty(), "Boon state crossed the camp boundary")
	_shift(false)
	game.queue_free()
	current_scene = null
	await _frames(5)
	if errors.is_empty():
		print("Boon choices passed: retained bonuses, explicit Shift sacrifice, input snapshot, four-target frost, five-way static/material interaction, guard choice, joint rollback and boon expiry")
	call_deferred("quit", 0 if errors.is_empty() else 1)
