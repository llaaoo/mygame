extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []

class Reject extends SkillExecutor:
	func execute(_skill: SkillData, _context: CastContext) -> bool:
		return false

class RejectSecond extends SkillExecutor:
	var count := 0
	func execute(skill: SkillData, context: CastContext) -> bool:
		count += 1
		return false if count == 2 else super.execute(skill, context)

class Target extends CharacterBody2D:
	var move_speed := 100.0
	var health: HealthComponent
	func take_damage(amount: int) -> void:
		health.take_damage(amount)

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _soul(game: MVPGame, point: Vector2) -> SoulRemnant:
	var soul := SoulRemnant.new()
	game.region_root.add_child(soul)
	soul.global_position = point
	return soul

func _request(game: MVPGame, source: String, empower := false) -> bool:
	var sm := game.player.skill_manager
	var inst := sm.get_instance(source)
	var context := CastContext.simple(game.player, Vector2.RIGHT, inst.data)
	context.empower = empower
	var accepted := sm.use_source(source, game.player, context)
	if accepted:
		sm.combinations.tick(0.65)
	return accepted

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	_check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	var runtime := GameRuntime.instance
	runtime.set_process(false)
	game._change_region("yard")
	var player := game.player
	var sm := player.skill_manager
	var controller := sm.combinations
	var buffs: BuffManager = player.get_node("BuffManager")
	var harvest := sm.pool.get_skill("soul_harvest")
	for entry in game.current_data.discoveries:
		if entry.id in ["soul_knowledge", "fire_knowledge"]:
			_check(game.progress_service.discover(entry), "Soul knowledge discovery did not grant")
	_check(sm.known_actions.has("soul_harvest") and game.progress.spell_rules.has("soul_water"), "Soul skill/rules not learned through exploration")
	sm.equip_slot(0, harvest)
	_check(not controller.preview(harvest, player).ready, "Harvest worked without a world soul")
	var enemy := game.active_enemies[0]
	player.global_position = enemy.global_position - Vector2(30, 0)
	CombatExecutor.report_hit(player, enemy, 2000, enemy.global_position)
	var soul := SoulRemnant.nearest(player, 150)
	_check(soul != null and soul.get_parent() == game.region_root, "Real encounter death did not create a region-owned soul")
	player.mana_component.max_mp = 500
	player.mana_component.mp = 500
	var original_position := player.global_position
	_check(sm.use_slot(0, player, Vector2.RIGHT), "Harvest preparation failed")
	player.global_position += Vector2(600, 0)
	controller.tick(0.65)
	_check(buffs.get_stack_count("soul_charge") == 0 and player.mana_component.mp == 500 and not soul.spent, "Leaving harvest range consumed a soul/resource")
	player.global_position = original_position
	controller.reset_session()
	var fading := _soul(game, player.global_position)
	fading.remaining = 0.1
	_check(sm.use_slot(0, player, Vector2.RIGHT), "Expiring soul did not prepare")
	runtime.get_simulation_runtime().tick(0.65)
	_check(buffs.get_stack_count("soul_charge") == 0 and not soul.spent and player.mana_component.mp == 500, "Expired soul was replaced silently with another source")
	controller.reset_session()
	var original_executor := sm.executor
	var reject := Reject.new()
	sm.add_child(reject)
	sm.executor = reject
	_check(_request(game, "slot_0"), "Rejected harvest did not prepare")
	_check(buffs.get_stack_count("soul_charge") == 0 and soul.available(player, 150) and player.mana_component.mp == 500, "Failed harvest lost its reserved soul or resources")
	sm.executor = original_executor
	reject.queue_free()
	_check(_request(game, "slot_0"), "Harvest retry failed")
	_check(buffs.get_stack_count("soul_charge") == 1 and soul.spent and player.mana_component.mp == 496, "Harvest did not atomically turn one world soul into a charge")
	buffs.apply_buff(harvest.buff_resource, player, harvest)
	buffs.apply_buff(harvest.buff_resource, player, harvest)
	var spare := _soul(game, player.global_position)
	controller.cooldowns.clear()
	_check(not controller.preview(harvest, player).ready and not spare.spent, "Full capacity consumed a world soul")
	var life := spare.remaining
	runtime.get_simulation_runtime().is_paused = true
	runtime.get_simulation_runtime().tick(60)
	_check(spare.remaining == life and not spare.is_queued_for_deletion(), "Paused simulation expired a world soul")
	runtime.get_simulation_runtime().is_paused = false
	spare.tick(60)
	_check(spare.is_queued_for_deletion(), "Remnant missed lifetime endpoint")

	# Move away from AI; real projectile collision verifies source and elemental utility.
	player.global_position = Vector2(16000, 16000)
	sm.restrict_actions = false
	sm.equip_slot(1, sm.pool.get_skill("ignite"))
	controller.reset_session()
	var target := Target.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 12
	target.add_child(shape)
	target.health = HealthComponent.new()
	target.health.name = "HealthComponent"
	target.health.max_hp = 1000
	target.health.regen_rate = 0
	target.add_child(target.health)
	var target_buffs := BuffManager.new()
	target_buffs.name = "BuffManager"
	target.add_child(target_buffs)
	target.collision_layer = 2
	target.collision_mask = 0
	target.position = player.position + Vector2(120, 0)
	game.region_root.add_child(target)
	target.health.setup(shape)
	for object in game.region_root.get_children():
		if object is SpellWorldObject and object.spec.id == "magic.soul_cache":
			object.global_position = player.global_position + Vector2(200, 0)
	target_buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres"))
	for i in range(3): await physics_frame
	var ordinary := controller.preview(sm.get_slot(1).data, player)
	var released := controller.preview(sm.get_slot(1).data, player, true)
	_check(ordinary.skill.get_id() == "ignite" and released.skill.get_id() == "soul_lance" and released.cost == 9 and released.status_conditions[0].stacks == 1, "Soul choice/charge preview is ambiguous")
	var events: Array[Dictionary] = []
	var changed := func(event: CombatEvent):
		if event.target == player:
			events.append(event.data)
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_STATUS_CHANGED, changed)
	var remaining: float = buffs.capture_status("soul_charge").remaining
	_check(_request(game, "slot_1", true), "Soul lance preparation rejected")
	await create_timer(0.4).timeout
	_check(buffs.get_stack_count("soul_charge") == 2 and buffs.capture_status("soul_charge").remaining == remaining and events.size() == 1 and events[0].amount == 1, "Partial consumption reset duration, removed all charges or published wrong facts")
	_check(game.progress.claims.has("magic.soul_cache"), "Soul attack did not reuse accepted hits to open the world cache")
	_check(not target_buffs.has_buff("frozen"), "Soul fire did not reuse the melting reaction")
	_check(target.health.hp < 1000 and target_buffs.has_buff("burning"), "Soul lance failed real collision/elemental status")

	# A soul and circle combine; a late rejection restores both, without consumption facts.
	var field := FireSigil.new()
	field.caster = player
	field.position = player.position
	game.region_root.add_child(field)
	controller.fields.append(field)
	controller.reset_session() # recreate below after cooldown reset
	field = FireSigil.new()
	field.caster = player
	field.position = player.position
	game.region_root.add_child(field)
	controller.fields.append(field)
	var multi := controller.preview(sm.get_slot(1).data, player, true)
	_check(multi.components.size() == 2 and multi.cost == 21, "Soul and field did not share total cost/plan")
	var reject_second := RejectSecond.new()
	sm.add_child(reject_second)
	sm.executor = reject_second
	var mp := player.mana_component.mp
	var notifications := events.size()
	_check(_request(game, "slot_1", true), "Multi-result action did not prepare")
	_check(reject_second.count == 2 and player.mana_component.mp == mp and field.charges == 2 and buffs.get_stack_count("soul_charge") == 2 and events.size() == notifications, "Late failure leaked field/status/resource consumption")
	sm.executor = original_executor
	reject_second.queue_free()
	controller.clear_field()
	controller.cooldowns.clear()
	controller.supplies.grant({"resin": 2})
	controller.supplies.configure("ignite", "resin")
	var material_plan := controller.preview(sm.get_slot(1).data, player, true)
	_check(material_plan.cost == 13 and material_plan.material_costs.get("resin") == 1 and material_plan.skill.impact_surface == "burning", "Existing material did not modify the soul result")

	# Cleansing and protection share the normal transaction and expire predictably.
	sm.equip_slot(2, sm.pool.get_skill("water_call"))
	for id in ["burning", "poison", "shocked"]:
		buffs.apply_buff(load("res://gameplay/abilities/data/%s.tres" % id))
	_check(_request(game, "slot_2", true), "Soul cleanse rejected")
	_check(buffs.has_buff("clear_mind") and not buffs.has_buff("poison") and not buffs.has_buff("burning") and not buffs.has_buff("shocked") and buffs.get_stack_count("soul_charge") == 1, "Cleanse did not remove statuses or consumed the wrong charge count")
	_check(not buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres")) and not buffs.has_buff("poison"), "Protection failed to block a matching status")
	_check(buffs.apply_buff(load("res://gameplay/abilities/data/frozen.tres")), "Protection incorrectly blocked unlisted control")
	buffs.remove_status("frozen")
	buffs.tick(6)
	_check(not buffs.has_buff("clear_mind") and buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres")), "Expired protection remained active")
	buffs.remove_status("poison")

	# The other two soul uses exercise real area control and defensive-to-offensive conversion.
	buffs.apply_buff(harvest.buff_resource, player, harvest)
	buffs.apply_buff(harvest.buff_resource, player, harvest)
	sm.equip_slot(3, sm.pool.get_skill("focus"))
	sm.equip_slot(4, sm.pool.get_skill("pulse"))
	target.position = player.position + Vector2(65, 0)
	target.health.invincible = false
	target_buffs.apply_buff(load("res://gameplay/abilities/data/wet.tres"))
	var target_hp := target.health.hp
	_check(_request(game, "slot_4", true), "Soul nova rejected")
	await create_timer(0.3).timeout
	_check(target.health.hp < target_hp and target_buffs.has_buff("frozen") and not target_buffs.has_buff("wet") and buffs.get_stack_count("soul_charge") == 2, "Soul nova did not share area/control/deep-freeze reactions")
	_check(_request(game, "slot_3", true) and buffs.has_buff("ancestral_ward") and buffs.get_stack_count("soul_charge") == 1, "Ancestral ward was not obtained through its soul combination")
	player.health_component.hp = player.health_component.max_hp
	player.health_component.invincible = false
	var blocked := CombatExecutor.report_hit(null, player, 20, player.global_position)
	_check(blocked.damage_dealt == 15, "Ancestral ward did not preserve its defensive benefit")
	controller.supplies.configure("ignite", "")
	controller.cooldowns.clear()
	var ward_release := controller.preview(sm.get_slot(1).data, player, true)
	_check(ward_release.cost == 11 and ward_release.skill.projectile_pierce == 2 and ward_release.consumed_boons.has("先祖护佑"), "Ancestral ward release did not combine its cost/shape with a soul result")
	_check(_request(game, "slot_1", true) and not buffs.has_buff("ancestral_ward") and not buffs.has_buff("soul_charge"), "Offensive release did not trade ward protection and the final charge")
	CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_STATUS_CHANGED, changed)
	game._change_region("camp")
	_check(not buffs.has_buff("soul_charge") and SoulRemnant.nearest(player, 100000) == null, "Soul resources survived region cleanup")
	await fixture.close()
	if failures.is_empty(): print("Soul spells passed: real deaths, world reservation, charges, physics, fields/materials, rollback, cleansing and cleanup")
	quit(0 if failures.is_empty() else 1)
