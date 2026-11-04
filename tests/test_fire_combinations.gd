extends SceneTree
## End-to-end T1 checks using the real player, executor, physics and mana components.

class DamageTarget extends CharacterBody2D:
	var hits := 0
	var damage_taken := 0
	func take_damage(amount: int) -> void:
		hits += 1
		damage_taken += amount

var failures: Array[String] = []
var committed: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in range(6):
		await process_frame
	var run: RunManager = game.get_node("RunManager")
	run.persist_meta = false
	var player: Player = run._player
	player.global_position = Vector2(12000, 12000)
	player.mana_component.mp_regen_rate = 0
	player.health_component.regen_rate = 0
	player.mana_component.max_mp = 200
	player.mana_component.mp = 200
	var sm: SkillManager = player.skill_manager
	var controller := sm.combinations
	controller.action_committed.connect(func(id: String): committed.append(id))
	var ignite := sm.pool.get_skill("ignite")
	var fireball := sm.pool.get_skill("fireball")
	sm.equip_hand("right", fireball)
	sm.equip_slot(5, fireball)
	_check(sm.right_hand.data.get_id() == "ignite" and sm.get_slot(5).data.get_id() == "ignite", "Combination result can be equipped directly")
	_check(not sm._execute(fireball, "right", player, Vector2.RIGHT), "Fireball cast directly without a field")
	for reward in run._build_skill_discovery_rewards():
		_check(reward.get("skill_id") != "fireball", "Fireball result offered as an equippable reward")
	_check(sm.get_slot(4).data.get_id() == "fire_sigil" and sm.get_slot(5).data.get_id() == "ignite", "Starter slots missing")
	_check(InputMap.has_action("skill_5") and InputMap.has_action("skill_6"), "Input actions missing")
	_check(controller.preview(ignite, player).rule_id == "", "Base ignition unexpectedly resolves a combo")
	Input.action_press("skill_5")
	for i in range(2):
		await physics_frame
	Input.action_release("skill_5")
	for i in range(2):
		await physics_frame
	_check(not controller.pending.is_empty(), "Real input did not start placement")
	_check(player.mana_component.mp == 200, "Preparation consumed MP early")
	await create_timer(0.95).timeout
	_check(is_instance_valid(controller.field), "Field was not created")
	if not is_instance_valid(controller.field):
		_finish()
		return
	_check(player.mana_component.mp == 192 and controller.field.charges == 2, "Placement cost or initial charges incorrect")
	var preview := controller.preview(ignite, player)
	_check(preview.rule_id == "fire_sigil_fireball" and preview.cost == 12, "In-field preview incorrect")
	var outsider := Node2D.new()
	game.add_child(outsider)
	outsider.global_position = player.global_position
	_check(SpellCombinationResolver.resolve(ignite, controller.field, outsider, controller.STARTER_RULE, true).rule_id == "", "Foreign actor can use field")
	_check(SpellCombinationResolver.resolve(ignite, controller.field, player, controller.STARTER_RULE, false).rule_id == "", "Unlearned recipe resolves")
	outsider.queue_free()

	# Real physics target receives one directed fireball hit; no local spark is also released.
	var target := DamageTarget.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10
	shape.shape = circle
	target.add_child(shape)
	target.collision_layer = 2
	target.collision_mask = 0
	run._room_root.add_child(target)
	target.global_position = player.global_position + Vector2(180, 0)
	var side_target := DamageTarget.new()
	var side_shape := CollisionShape2D.new()
	side_shape.shape = circle.duplicate()
	side_target.add_child(side_shape)
	side_target.collision_layer = 2
	side_target.collision_mask = 0
	run._room_root.add_child(side_target)
	side_target.global_position = player.global_position + Vector2(0, 60)
	await physics_frame
	_check(sm.use_slot(5, player, Vector2.RIGHT), "Combo did not start")
	await create_timer(0.8).timeout
	_check(player.mana_component.mp == 180 and controller.field.charges == 1, "Combo did not consume exactly 12 MP and one charge")
	_check(committed.count("fireball") == 1 and not committed.has("ignite"), "Both base and combo executed")
	_check(target.hits == 1 and target.damage_taken > 0, "Combo failed real physics damage or hit twice")
	_check(side_target.hits == 0, "Fireball still behaves as a radial field burst")
	target.global_position += Vector2(0, 1000)
	_check(not sm.use_slot(5, player, Vector2.RIGHT), "Combo bypassed shared cooldown")

	# Pausing freezes the field, cooldowns and the central simulation.
	var remaining := controller.field.remaining
	var cooldown: float = controller.cooldowns.fire_sigil_fireball
	var mana_before := player.mana_component.mp
	paused = true
	await create_timer(0.2, true).timeout
	_check(controller.field.remaining == remaining and controller.cooldowns.fire_sigil_fireball == cooldown, "Pause advanced field or cooldown")
	_check(player.mana_component.mp == mana_before, "Pause changed mana")
	paused = false
	await create_timer(2.1).timeout

	# A matching recipe must fail, rather than silently cast the cheaper base spell.
	player.mana_component.mp = 11
	_check(not sm.use_slot(5, player, Vector2.RIGHT), "Insufficient combo MP accepted")
	_check(player.mana_component.mp == 11 and controller.field.charges == 1, "Rejected action consumed resources")
	player.mana_component.mp = 100
	_check(sm.use_slot(5, player, Vector2.RIGHT), "Leave-field test did not start: %s / %s" % [controller.last_message, controller.cooldowns])
	player.global_position += Vector2(200, 0)
	await create_timer(0.4).timeout
	_check(player.mana_component.mp == 100 and controller.field.charges == 1, "Leaving field consumed resources or downgraded")
	_check(committed.count("fireball") == 1, "Invalid combo executed")
	await create_timer(0.35).timeout

	# Outside the field the same input performs ordinary ignition at the base cost.
	side_target.global_position = player.global_position + Vector2(30, 0)
	target.global_position = player.global_position + Vector2(180, 0)
	target.hits = 0
	_check(sm.use_slot(5, player, Vector2.RIGHT), "Base ignition did not start")
	await create_timer(0.35).timeout
	_check(player.mana_component.mp == 96 and committed.count("ignite") == 1, "Base ignition cost/result incorrect")
	_check(side_target.hits == 1 and target.hits == 0, "Spark must hit only nearby targets without launching a fireball")
	side_target.global_position += Vector2(0, 1000)
	target.global_position += Vector2(0, 1000)
	await create_timer(0.65).timeout
	player.global_position = controller.field.global_position
	_check(sm.use_slot(5, player, Vector2.RIGHT), "Last-charge combo did not start")
	await create_timer(0.4).timeout
	_check(player.mana_component.mp == 84 and committed.count("fireball") == 2, "Last charge not consumed once")
	_check(not is_instance_valid(controller.field), "Depleted field was not removed")

	# Cancellation and invalid placement keep resources and an existing field intact.
	controller.cooldowns.clear()
	_check(sm.use_slot(4, player, Vector2.RIGHT), "Cancelled placement did not start")
	controller.cancel("test dodge")
	await create_timer(0.9).timeout
	_check(player.mana_component.mp == 84 and not is_instance_valid(controller.field), "Cancelled placement consumed resources")
	_check(sm.use_slot(4, player, Vector2.RIGHT), "Replacement setup did not start")
	await create_timer(0.9).timeout
	var previous: FireSigil = controller.field
	controller.cooldowns.clear()
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 30)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	wall.collision_layer = 1
	game.add_child(wall)
	wall.global_position = player.global_position + Vector2(60, 0)
	await physics_frame
	var before := player.mana_component.mp
	_check(not sm.use_slot(4, player, Vector2.RIGHT), "Blocked placement accepted")
	_check(controller.field == previous and player.mana_component.mp == before, "Invalid replacement removed old field or MP")
	wall.queue_free()
	await physics_frame
	_check(sm.use_slot(4, player, Vector2.RIGHT), "Damage interruption did not start")
	player.health_component.hp -= 1
	await create_timer(0.9).timeout
	_check(controller.field == previous and player.mana_component.mp == before, "Damage interruption consumed resources")
	# Stable action cooldown survives moving an action to another slot.
	controller.cooldowns.ignite = 1.0
	sm.equip_slot(0, ignite)
	_check(not sm.use_slot(0, player, Vector2.RIGHT), "Changing slots bypassed ignition cooldown")
	controller.cooldowns.ignite = 0.0
	# Expiry during preparation must cancel, not fall back to ordinary ignition.
	previous.remaining = 0.1
	_check(sm.use_slot(5, player, Vector2.RIGHT), "Expiry test did not start")
	await create_timer(0.4).timeout
	_check(player.mana_component.mp == before and controller.pending.is_empty(), "Expired field consumed resources")
	await create_timer(0.35).timeout
	controller.cooldowns.clear()
	_check(sm.use_slot(4, player, Vector2.RIGHT), "Oil reaction setup did not start")
	await create_timer(0.9).timeout
	var barrel: MapObject = load("res://world/object/oil_barrel.tscn").instantiate()
	run._room_root.add_child(barrel)
	barrel.global_position = player.global_position + Vector2(180, 0)
	await physics_frame
	_check(sm.use_slot(5, player, Vector2.RIGHT), "Oil reaction combo did not start")
	await create_timer(0.85).timeout
	_check(barrel.get_state().state in ["DESTROYED", "RESPAWNING"], "Fireball did not destroy a real oil barrel")
	var cell := Vector2i(floori(barrel.global_position.x / 64), floori(barrel.global_position.y / 64))
	var surface := GameRuntime.instance.get_simulation_runtime().get_surface_manager().get_surface(cell)
	_check(surface.get("state", "") == "burning", "Oil barrel destruction did not produce a fire reaction")
	# Origin is a valid AoE target even with a translated parent.
	var offset_root := Node2D.new()
	game.add_child(offset_root)
	offset_root.position = Vector2(40000, 50000)
	var legacy_aoe := load("res://gameplay/abilities/data/fire_sigil_burst_data.tres") as SkillData
	var ctx := CastContext.at_position(player, Vector2.ZERO, legacy_aoe)
	ctx.world = offset_root
	_check(sm.executor.execute(legacy_aoe, ctx), "Origin-target effect failed")
	await process_frame
	_check(offset_root.get_child_count() == 1 and offset_root.get_child(0).global_position == Vector2.ZERO, "AoE ignored origin or parent transform")
	offset_root.queue_free()
	await create_timer(0.4).timeout
	controller.cooldowns.clear()
	# Remove only the test fire status so the scope check measures region invalidation.
	player.get_node("BuffManager").remove_status("burning")
	before = player.mana_component.mp
	# Scope deletion invalidates both the field and a pending action.
	_check(sm.use_slot(5, player, Vector2.RIGHT), "Scope test did not start")
	run._room_root.queue_free()
	await create_timer(0.4).timeout
	_check(controller.pending.is_empty() and player.mana_component.mp == before, "Region removal accepted stale plan")
	# Let the existing damage invulnerability timer settle before tearing down the tree.
	player.global_position += Vector2(2000, 2000)
	player.get_node("BuffManager").remove_status("burning")
	await create_timer(0.6).timeout
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("Fire combination tests passed: real damage, costs, ownership, cooldown, pause, interruption and cleanup")
	# Finish after the currently emitting timer signal has unwound.
	call_deferred("quit", 0 if failures.is_empty() else 1)
