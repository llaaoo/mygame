extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []

class Target extends CharacterBody2D:
	var move_speed := 100.0
	var health: HealthComponent
	var calls := 0
	func take_damage(amount: int) -> void:
		calls += 1
		health.take_damage(amount)

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _target(game: MVPGame) -> Target:
	var target := Target.new()
	target.health = HealthComponent.new()
	target.health.name = "HealthComponent"
	target.health.max_hp = 1000
	target.health.hp = 1000
	target.health.regen_rate = 0
	target.add_child(target.health)
	var buffs := BuffManager.new()
	buffs.name = "BuffManager"
	target.add_child(buffs)
	game.region_root.add_child(target)
	target.position = game.player.position + Vector2(40, 0)
	return target

func _reset(target: Target) -> BuffManager:
	var buffs := target.get_node("BuffManager") as BuffManager
	buffs.clear_all()
	target.health.hp = 1000
	target.health.invincible = false
	target.calls = 0
	return buffs

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / 64), floori(point.y / 64))

func _cast(game: MVPGame, slot: int, context: CastContext = null) -> void:
	var sm := game.player.skill_manager
	var skill := sm.get_slot(slot).data
	if not context: context = CastContext.simple(game.player, Vector2.RIGHT, skill)
	sm.combinations.cooldowns.clear()
	_check(sm.use_source("slot_%d" % slot, game.player, context), "Existing action rejected: " + skill.get_id())
	sm.combinations.tick(0.4)
	for i in range(3): await process_frame

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	var runtime := GameRuntime.instance
	runtime.set_process(false)
	var player := game.player
	var sm := player.skill_manager
	var sim := runtime.get_simulation_runtime()
	var surfaces := sim.get_surface_manager()
	player.global_position = Vector2(10000, 10000)
	player.mana_component.max_mp = 500
	player.mana_component.mp = 500
	sm.restrict_actions = false
	var counts := [game.catalog.actions.size(), game.catalog.spell_rules.size(), game.catalog.equipment.size(), sm.combinations.supplies.catalog.size()]
	var spark := sm.pool.get_skill("ignite")
	var pulse := sm.pool.get_skill("pulse")
	var water := sm.pool.get_skill("water_call")
	var target := _target(game)
	var buffs := _reset(target)
	var reactions: Array[String] = []
	var resolver := player.get_node("SkillSynergyResolver") as SkillSynergyResolver
	resolver.reaction_triggered.connect(func(title: String, _position: Vector2): reactions.append(title))

	# The small basic spark now follows the same fire properties as the expensive projectile.
	buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres"))
	var hit := CombatExecutor.report_hit(player, target, 100, target.position, spark, spark.tags)
	_check(hit.damage_dealt == 160 and target.calls == 2 and not buffs.has_buff("frozen") and buffs.has_buff("burning") and reactions == ["融化"], "Basic spark did not reuse fire reaction/control conversion")
	buffs = _reset(target)
	reactions.clear()
	buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres"))
	var fireball := sm.pool.get_skill("fireball")
	hit = CombatExecutor.report_hit(player, target, 100, target.position, fireball, fireball.tags)
	_check(hit.damage_dealt == 160 and reactions == ["融化"], "Explicit plus shared reaction executed twice")

	# Newly applied conditions cannot also count as pre-existing preparation on the same hit.
	buffs = _reset(target)
	reactions.clear()
	var mixed := SkillData.new()
	mixed.tags = ["fire", "poison"]
	hit = CombatExecutor.report_hit(player, target, 100, target.position, mixed, mixed.tags)
	_check(hit.damage_dealt == 100 and buffs.has_buff("poison") and reactions.is_empty(), "A mixed hit detonated its own newly applied poison")
	target.health.invincible = false
	hit = CombatExecutor.report_hit(player, target, 100, target.position, spark, spark.tags)
	_check(hit.damage_dealt == 175 and not buffs.has_buff("poison"), "A later spark did not detonate prepared poison")

	# One area attack may detonate multiple prepared targets; only repeat hits on that target throttle.
	var first := _target(game)
	var second := _target(game)
	(first.get_node("BuffManager") as BuffManager).apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	(second.get_node("BuffManager") as BuffManager).apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	var a := CombatExecutor.report_hit(player, first, 100, first.position, spark, spark.tags)
	var b := CombatExecutor.report_hit(player, second, 100, second.position, spark, spark.tags)
	_check(a.damage_dealt == 175 and b.damage_dealt == 175, "Reaction cooldown swallowed another target in the same attack")
	first.health.invincible = false
	(first.get_node("BuffManager") as BuffManager).apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	hit = CombatExecutor.report_hit(player, first, 100, first.position, spark, spark.tags)
	_check(hit.damage_dealt == 100, "Same-target reaction cooldown did not throttle repeated hits")
	resolver.tick(0.2)
	first.health.invincible = false
	hit = CombatExecutor.report_hit(player, first, 100, first.position, spark, spark.tags)
	_check(hit.damage_dealt == 175 and resolver._cooldowns.size() == 1, "Simulated reaction cooldown failed to expire/prune")

	buffs = _reset(target)
	reactions.clear()
	buffs.apply_buff(load("res://gameplay/abilities/data/burning.tres"))
	buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	hit = CombatExecutor.report_hit(player, target, 0, target.position, water, water.tags)
	_check(hit.damage_dealt == 0 and target.calls == 0 and buffs.has_buff("wet") and not buffs.has_buff("poison") and not buffs.has_buff("burning") and reactions == ["灭火"], "Water lost its zero-damage cleansing role")

	buffs = _reset(target)
	reactions.clear()
	buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres"))
	hit = CombatExecutor.report_hit(player, target, 100, target.position, pulse, pulse.tags, "pulse")
	_check(hit.damage_dealt == 150 and not buffs.has_buff("frozen") and is_equal_approx(target.move_speed, 100) and reactions == ["碎冰"], "Pulse did not exchange remaining freeze control for damage")
	hit = CombatExecutor.report_hit(player, target, 100, target.position, pulse, pulse.tags, "pulse")
	_check(hit.damage_dealt == 100 and reactions.size() == 1, "A subsequent pulse reused consumed freeze")
	buffs = _reset(target)
	reactions.clear()
	target.health.invincible = true
	buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres"))
	hit = CombatExecutor.report_hit(player, target, 100, target.position, pulse, pulse.tags)
	_check(not hit.accepted and buffs.has_buff("frozen") and reactions.is_empty(), "Rejected hit consumed preparation or displayed a reaction")

	# Existing world tools create a chain: thaw a blocked water connection, then conduct through it.
	player.global_position = Vector2(12832, 12832)
	var origin := _cell(player.global_position)
	surfaces.force_set_surface(origin + Vector2i.LEFT, "wet", 12)
	surfaces.force_set_surface(origin, "frozen", 5)
	surfaces.force_set_surface(origin + Vector2i.RIGHT, "wet", 12)
	surfaces.force_set_surface(origin + Vector2i(3, 0), "wet", 12)
	sm.equip_slot(0, pulse)
	await _cast(game, 0)
	_check(surfaces.get_surface(origin).get("state") == "wet", "Actual pulse did not shatter frozen terrain")
	surfaces.apply_tags(origin + Vector2i.LEFT, ["lightning"])
	_check(surfaces.get_surface(origin + Vector2i.RIGHT).get("state") == "electrified" and surfaces.get_surface(origin + Vector2i(3, 0)).get("state") == "wet", "Broken ice failed to reconnect water or conductivity crossed a dry gap")

	# Small fire must affect its own grid cell, even near a corner with no cell center inside radius.
	player.global_position = Vector2(15360, 15360)
	origin = _cell(player.global_position + Vector2(24, 0))
	surfaces.force_set_surface(origin, "oiled", 12)
	sm.equip_slot(0, spark)
	await _cast(game, 0)
	_check(surfaces.get_surface(origin).get("state") == "burning", "Basic spark failed to ignite oil at a grid edge")

	# Ground placement lets the same water tool save the caster without a new cleansing spell.
	player.global_position = Vector2(18016, 18016)
	sm.equip_slot(1, water)
	var caster_buffs := player.get_node("BuffManager") as BuffManager
	caster_buffs.apply_buff(load("res://gameplay/abilities/data/burning.tres"))
	caster_buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	var mana := player.mana_component.mp
	var self_point := player.global_position
	await _cast(game, 1, CastContext.at_position(player, self_point, water))
	sim.tick(0.5)
	_check(surfaces.get_surface(_cell(self_point)).get("state") == "wet" and not caster_buffs.has_buff("burning") and not caster_buffs.has_buff("poison") and player.mana_component.mp == mana - 5, "Self-placed water did not reuse normal cost/terrain cleansing")

	# Input and aiming share the same bounded point; preparation locks it until release.
	var actions: Array[Action] = []
	Input.action_press("skill_2")
	player.input_controller._poll_universal_cast(actions, "slot_1", "skill_2")
	Input.action_release("skill_2")
	var expected := CastContext.ground_point(player, player.get_global_mouse_position(), water.cast_distance)
	_check(actions.size() == 1 and actions[0].cast_context.has_target_position and actions[0].cast_context.target_position.is_equal_approx(expected), "Input did not capture the ground target once")
	player.casting.show_aim("slot_1", sm.get_slot(1).data)
	player.casting.tick(0)
	_check(player.casting._aim_dot.global_position.is_equal_approx(expected), "Aim indicator disagreed with the actual bounded ground point")
	_check(player.casting._aim_ring.visible and is_equal_approx(player.casting._aim_ring.points[0].length(), water.aoe_visual.radius), "Ground area preview did not show the actual effect radius")
	player.casting.hide_aim()
	var context := CastContext.at_position(player, player.global_position + Vector2(1000, 0), water)
	sm.combinations.cooldowns.clear()
	_check(sm.use_source("slot_1", player, context), "Bounded ground cast rejected")
	var locked := sm.combinations.pending.target_position
	_check(is_equal_approx(locked.distance_to(player.global_position), water.cast_distance), "Explicit ground request bypassed range")
	player.casting.tick(0)
	_check(player.casting._aim_ring.visible and player.casting._aim_ring.global_position.is_equal_approx(locked), "Ground preparation lost its locked area marker")
	context.target_position = player.global_position - Vector2(1000, 0)
	player.global_position += Vector2(20, 0)
	sm.combinations.tick(0.4)
	for i in range(3): await process_frame
	var found := false
	for child in game.region_root.get_children():
		if child is PersistentAOE and child.global_position.is_equal_approx(locked): found = true
	_check(found, "Prepared ground cast resampled context or caster position")
	_check(counts == [game.catalog.actions.size(), game.catalog.spell_rules.size(), game.catalog.equipment.size(), sm.combinations.supplies.catalog.size()], "Deepening existing interactions changed authored spell/material/equipment counts")
	await fixture.close()
	if failures.is_empty(): print("Existing spell interactions passed: property reuse, pre-hit snapshots, per-target reactions, shattering, world chains and bounded ground input")
	quit(0 if failures.is_empty() else 1)
