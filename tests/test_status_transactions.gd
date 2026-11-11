extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []

class Target extends CharacterBody2D:
	var move_speed := 100.0
	var health: HealthComponent
	func take_damage(amount: int) -> void:
		health.take_damage(amount)
	func heal(amount: int) -> void:
		health.heal(amount)

class CountingAOE extends PersistentAOE:
	var hits := 0
	func _emit_hit_event(_target: Node2D) -> void:
		hits += 1

class RejectSecond extends SkillExecutor:
	var attempts := 0
	func execute(skill: SkillData, context: CastContext) -> bool:
		attempts += 1
		return false if attempts == 2 else super.execute(skill, context)

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _target(game: MVPGame) -> Target:
	var target := Target.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	shape.shape = circle
	target.add_child(shape)
	target.health = HealthComponent.new()
	target.health.name = "HealthComponent"
	target.health.regen_rate = 0
	target.add_child(target.health)
	var buffs := BuffManager.new()
	buffs.name = "BuffManager"
	target.add_child(buffs)
	var stats := StatsComponent.new()
	stats.intelligence = 100
	stats.name = "StatsComponent"
	target.add_child(stats)
	target.position = game.player.position + Vector2(200, 0)
	target.collision_layer = 2
	target.collision_mask = 0
	game.region_root.add_child(target)
	target.health.setup(shape)
	return target

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	_check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	var player := game.player
	var sm := player.skill_manager
	var controller := sm.combinations
	var supplies := controller.supplies
	var buffs: BuffManager = player.get_node("BuffManager")
	player.mana_component.max_mp = 300
	player.mana_component.mp = 300
	for rule in controller.rules:
		controller.learned_rules[rule.id] = true
	var ember := load("res://gameplay/abilities/data/ember_focus_result.tres") as SkillData
	buffs.apply_buff(ember.buff_resource, player, ember)
	var attack := player.combat_component.attack_damage
	for kind in ["fire", "frost"]:
		var field := FireSigil.new()
		field.caster = player
		field.field_type = kind
		field.position = player.position
		game.region_root.add_child(field)
		controller.fields.append(field)
	supplies.grant({"resin": 4})
	supplies.configure("ignite", "resin")
	player.mana_component._time_since_use = 1.25
	player.mana_component._regen_accumulator = 0.4
	var notifications := [0, 0, 0, 0]
	var reasons: Array[String] = []
	buffs.buffs_changed.connect(func(): notifications[0] += 1)
	player.mana_component.mp_changed.connect(func(_a, _b): notifications[1] += 1)
	supplies.changed.connect(func(): notifications[2] += 1)
	var removed := func(event: CombatEvent):
		if event.target == player and event.data.get("status_id") == "ember_focus":
			notifications[3] += 1
			reasons.append(event.data.reason)
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_STATUS_REMOVED, removed)
	var original := sm.executor
	var reject := RejectSecond.new()
	sm.add_child(reject)
	sm.executor = reject
	var context := CastContext.simple(player, Vector2.RIGHT, sm.right_hand.data)
	context.empower = true
	_check(sm.use_source("right", player, context), "Transaction test did not prepare")
	controller._commit()
	_check(reject.attempts == 2 and buffs.has_buff("ember_focus") and player.combat_component.attack_damage == attack, "Late failure did not restore the original status/attributes")
	_check(notifications == [0, 0, 0, 0] and supplies.count("resin") == 4 and player.mana_component.mp == 300, "Failed transaction published resource/status notifications")
	_check(player.mana_component._time_since_use == 1.25 and player.mana_component._regen_accumulator == 0.4, "Failure changed regeneration timing")
	_check(controller.fields[0].charges == 2 and controller.fields[1].charges == 2, "Failure lost field charges")
	sm.executor = original
	reject.queue_free()
	_check(sm.use_source("right", player, context), "Retry after rollback rejected")
	controller._commit()
	_check(notifications == [1, 1, 1, 1] and reasons == ["consumed"] and not buffs.has_buff("ember_focus"), "Successful consumption did not publish exactly once after commit")
	CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_STATUS_REMOVED, removed)
	controller.reset_session()
	supplies.configure("ignite", "")
	await process_frame
	for node in get_nodes_in_group("projectile"):
		node.queue_free()
	var target := _target(game)
	var target_buffs: BuffManager = target.get_node("BuffManager")
	var fire := sm.pool.get_skill("fireball")
	target.health.invincible = true
	var hit := CombatExecutor.report_hit(player, target, 10, target.position, fire, ["fire"], "action-a")
	_check(not hit.accepted and hit.rejection == "invincible" and not target_buffs.has_buff("burning"), "Rejected hit still applied a status")
	target.health.invincibility_blocks_status = false
	hit = CombatExecutor.report_hit(player, target, 10, target.position, fire, ["fire"], "action-a")
	_check(hit.accepted and not hit.damage_accepted and hit.status_accepted and hit.damage_dealt == 0 and target_buffs.has_buff("burning"), "Damage-only invulnerability policy was ignored")
	target_buffs.clear_all()
	target.health.invincibility_blocks_status = true
	target.health.invincible = false
	var water := sm.pool.get_skill("water_call")
	hit = CombatExecutor.report_hit(player, target, 0, target.position, water, ["water"])
	_check(hit.accepted and target_buffs.has_buff("wet") and target.health.hp == 100, "Zero-damage utility lost accepted status hits")
	target_buffs.clear_all()
	hit = CombatExecutor.report_hit(player, target, 10, target.position, null, [], "family")
	var same := CombatExecutor.report_hit(player, target, 10, target.position, null, [], "family")
	var other := CombatExecutor.report_hit(player, target, 10, target.position, null, [], "other")
	_check(hit.damage_dealt == 10 and same.damage_dealt == 10 and not other.accepted and target.health.hp == 80, "Common-action damage and independent hit invulnerability diverged")

	# Inclusive lifetime endpoint; partitioning time cannot add or remove periodic effects.
	for deltas in [[1.0, 1.0], [2.0], [0.35, 0.7, 0.95], [4.0]]:
		target.health.hp = 20
		var hot := Buff.new()
		hot.status_id = "test_hot"
		hot.duration = 2
		hot.tick_interval = 1
		hot.tick_heal = 5
		target_buffs.apply_buff(hot)
		for delta in deltas:
			target_buffs.tick(delta)
		_check(target.health.hp == 30 and not target_buffs.has_buff("test_hot"), "Periodic expiry depended on delta partition or lost its final tick")
	target.health.invincible = false
	target.health.hp = 100
	var dot := Buff.new()
	dot.status_id = "test_dot"
	dot.duration = 2
	dot.tick_interval = 1
	dot.tick_damage = 4
	dot.tick_damage_scaling = 0.5
	target_buffs.apply_buff(dot, player, fire)
	target_buffs.tick(1)
	var expected := 4 + int(player.stats_component.magic_damage * 0.5)
	_check(target.health.hp == 100 - expected and not target_buffs.has_buff("burning"), "DOT used victim stats or retriggered direct-hit fire application")
	target.health.tick(1)
	target_buffs.tick(1)
	_check(not target_buffs.has_buff("test_dot") and target.health.hp == 100 - expected * 2, "DOT refresh loop or terminal tick error")
	for deltas in [[2.0], [0.35, 0.7, 0.95], [4.0]]:
		target.health.hp = 100
		target.health.invincible = true
		target_buffs.apply_buff(dot, player, fire)
		for delta in deltas:
			target_buffs.tick(delta)
		_check(target.health.hp == 100 - expected * 2 and not target_buffs.has_buff("test_dot"), "Applied DOT depended on frame partition or contact invulnerability")
	var kill_source: Array = []
	var kill_listener := func(event: CombatEvent):
		if event.target == target:
			kill_source.append(event.source)
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_KILL, kill_listener)
	target.health.hp = 1
	target.health.invincible = false
	target_buffs.apply_buff(dot, player, fire)
	target_buffs.tick(1)
	_check(kill_source == [player], "Periodic kill lost its original caster")
	CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_KILL, kill_listener)

	var base_speed := player.move_speed
	var primary := player.stats_component.strength
	var boost := Buff.new()
	boost.status_id = "test_attributes"
	boost.stat_modifiers = {"move_speed": 10, "strength": 5}
	boost.stat_multipliers = {"move_speed": 0.2}
	boost.speed_multiplier = 1.3
	buffs.apply_buff(boost)
	_check(is_equal_approx(player.move_speed, (base_speed + 10) * 1.2 * 1.3) and player.stats_component.strength == primary and player.stats_component.effective_stat("strength") == primary + 5, "Base attributes were mixed with temporary contributions")
	player.stats_component.modify_stat("agility", 1)
	_check(is_equal_approx(player.move_speed, (base_speed + 13) * 1.2 * 1.3), "Growth during a compound buff was not recomputed")
	buffs.remove_status("test_attributes")
	_check(is_equal_approx(player.move_speed, base_speed + 3) and player.stats_component.strength == primary, "Attribute removal left drift")
	var equipment: EquipmentManager = player.get_node("EquipmentManager")
	var boots := EquipmentData.new()
	boots.stat_modifiers = {"move_speed": 15}
	boots.slot_type = EquipmentData.SlotType.FEET
	equipment.equip(boots)
	buffs.clear_temporary()
	_check(is_equal_approx(player.move_speed, base_speed + 18) and equipment.get_equipment(EquipmentData.SlotType.FEET) == boots, "Region cleanup removed persistent equipment effects")

	# Physics establishes overlap; deterministic updates verify all endpoint pulses.
	var aoe_target := _target(game)
	aoe_target.position = Vector2(20000, 20000)
	for deltas in [[1.0, 1.0], [2.0], [0.35, 0.7, 0.95], [4.0]]:
		var aoe := CountingAOE.new()
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		aoe.add_child(sprite)
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		shape.shape = CircleShape2D.new()
		aoe.add_child(shape)
		var definition := SkillData.new()
		definition.skill_type = SkillData.SkillType.AOE
		definition.aoe_radius = 50
		definition.aoe_lifetime = 2
		definition.aoe_tick_interval = 1
		definition.aoe_max_hits_per_target = 3
		definition.ignites_dry_surface = false
		aoe.setup(definition, player)
		aoe.position = aoe_target.position
		game.region_root.add_child(aoe)
		aoe.set_physics_process(false)
		for i in range(3): await physics_frame
		for delta in deltas:
			aoe._physics_process(delta)
		_check(aoe.hits == 3 and aoe.is_queued_for_deletion(), "AoE overlap or terminal pulses depended on delta partition")
		await process_frame
	var surfaces := SurfaceScheduler.new()
	surfaces.set_surface(Vector2i.ZERO, "frozen", 2)
	surfaces.tick(3)
	_check(surfaces.get_surface(Vector2i.ZERO).state == "wet" and is_equal_approx(surfaces.get_surface(Vector2i.ZERO).remaining, 3), "Surface expiry lost overshoot time")
	surfaces.tick(3)
	_check(surfaces.get_surface(Vector2i.ZERO).state == "dry", "Surface successor did not expire at its endpoint")
	surfaces.free()
	await fixture.close()
	if failures.is_empty():
		print("Status transactions passed: atomic notifications/resources, hit policies, utility/families, periodic boundaries/source, attribute rebuild and persistent cleanup")
	quit(0 if failures.is_empty() else 1)
