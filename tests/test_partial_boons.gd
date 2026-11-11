extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
class RejectingExecutor extends SkillExecutor:
	func execute(_skill: SkillData, _context: CastContext) -> bool: return false

func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(false)
	var player := game.player
	player.global_position = Vector2(21000, 21000)
	player.mana_component.max_mp = 1000
	player.mana_component.mp = 1000
	var sm := player.skill_manager
	sm.restrict_actions = false
	var controller := sm.combinations
	var supplies := controller.supplies
	supplies.grant({"frost_salt": 20})
	supplies.configure("water_call", "frost_salt")
	var buffs := player.get_node("BuffManager") as BuffManager
	var equipment := player.get_node("EquipmentManager") as EquipmentManager
	var water := sm.pool.get_skill("water_call")
	var frost := sm.pool.get_skill("frost_stride")
	sm.equip_slot(0, water)
	buffs.apply_buff(frost.buff_resource, player, frost)
	supplies.configure("water_call", "")
	check(controller.preview(water, player, true).consumed_boons.is_empty(), "Shared water affinity made liquid water spend the frost-specific boon")
	supplies.configure("water_call", "frost_salt")
	var normal := controller.preview(water, player)
	var full := controller.preview(water, player, true)
	check(normal.cost == 7 and normal.skill.aoe_visual.radius == 135 and full.cost == 10 and full.skill.aoe_visual.radius == 171, "Ordinary/full utility boon behavior changed")
	equipment.equip(game.catalog.equipment.cadence_gloves)
	var partial := controller.preview(water, player, true)
	var snapshot := buffs.capture_status("frost_stride")
	check(partial.cost == 15 and partial.partial_boons.has("霜行") and partial.consumed_boons.is_empty() and partial.skill.aoe_visual.radius == 171, "Partial boon cost, shape or preview incorrect")
	check(buffs.capture_status("frost_stride").remaining == snapshot.remaining, "Partial preview mutated lifetime")
	var context := CastContext.at_position(player, player.global_position + Vector2(96, 0), water)
	context.empower = true
	var before := player.mana_component.mp
	check(sm.use_source("slot_0", player, context), "Partial cast failed to prepare")
	controller.tick(.4)
	for i in range(3): await process_frame
	var after := buffs.capture_status("frost_stride")
	check(after.instance == snapshot.instance and after.instance.source_ref.get_ref() == player and is_equal_approx(after.remaining, snapshot.remaining * .5) and is_equal_approx(buffs.get_speed_multiplier(), 1.3), "Partial consumption replaced the source, refreshed lifetime or removed mobility")
	check(player.mana_component.mp == before - 15 and supplies.count("frost_salt") == 19, "Partial cast charged wrong costs")
	controller.cooldowns.clear()
	supplies.configure("water_call", "frost_salt")
	check(sm.use_source("slot_0", player, context), "Repeated partial cast failed")
	controller.tick(.4)
	check(is_equal_approx(buffs.capture_status("frost_stride").remaining, snapshot.remaining * .25), "Repeated release refreshed rather than halved the remaining time")
	# Damage uses retained factor; shape still receives the release bonus.
	var bolt := sm.pool.get_skill("frost_bolt")
	var modified := BoonSpellModifier.plan(bolt, player, true)
	check(modified.skill.damage == int(round(bolt.damage * 1.2)) and modified.skill.projectile_pierce == 2 and modified.conditions[0].cost == 6, "Partial release did not trade burst damage for retained benefit")
	equipment.equip(game.catalog.equipment.covenant_ring)
	modified = BoonSpellModifier.plan(bolt, player, true)
	check(modified.skill.damage == int(round(bolt.damage * 1.45)) and modified.conditions[0].cost == 8, "Partial release lost the existing covenant bonus/surcharge")
	equipment.unequip(EquipmentData.SlotType.RING)
	# Late execution rejection restores lifetime, revision, costs and all notifications.
	controller.cooldowns.clear()
	snapshot = buffs.capture_status("frost_stride")
	var revision := buffs.status_version("frost_stride")
	before = player.mana_component.mp
	var salt := supplies.count("frost_salt")
	var notifications := [0]
	buffs.buffs_changed.connect(func(): notifications[0] += 1)
	var original := sm.executor
	var reject := RejectingExecutor.new()
	sm.add_child(reject)
	sm.executor = reject
	supplies.configure("water_call", "frost_salt")
	check(sm.use_source("slot_0", player, context), "Rollback preparation failed")
	controller.tick(.4)
	check(buffs.capture_status("frost_stride").remaining == snapshot.remaining and buffs.status_version("frost_stride") == revision and notifications[0] == 0 and player.mana_component.mp == before and supplies.count("frost_salt") == salt, "Rejected partial release leaked lifetime, revision, facts or costs")
	sm.executor = original
	reject.queue_free()
	controller.cooldowns.clear()
	check(sm.use_source("slot_0", player, context), "Equipment-change preparation failed")
	equipment.unequip(EquipmentData.SlotType.HANDS)
	controller.tick(.4)
	check(controller.pending.is_empty() and player.mana_component.mp == before and supplies.count("frost_salt") == salt and buffs.capture_status("frost_stride").remaining == snapshot.remaining, "Unequipping changed a prepared partial release into a full release")
	equipment.equip(game.catalog.equipment.cadence_gloves)
	controller.reset_session()
	check(sm.use_source("slot_0", player, context), "Expiry preparation failed")
	buffs.tick(10)
	controller.tick(.4)
	check(controller.pending.is_empty() and player.mana_component.mp == before and supplies.count("frost_salt") == salt and not buffs.has_buff("frost_stride"), "Expired partial boon silently degraded the accepted cast")
	# Multiple components charge and halve the same boon once.
	buffs.clear_all()
	controller.reset_session()
	for type in ["fire", "frost"]:
		var field := FireSigil.new()
		field.caster = player
		field.field_type = type
		game.region_root.add_child(field)
		field.global_position = player.global_position
		controller.fields.append(field)
		controller.field = field
	controller.learned_rules["frost_sigil_spark"] = true
	controller.learned_rules["fire_sigil_fireball"] = true
	var ward := sm.pool.get_skill("ancestral_ward")
	buffs.apply_buff(ward.buff_resource, player, ward)
	snapshot = buffs.capture_status("ancestral_ward")
	var spark := sm.pool.get_skill("ignite")
	sm.equip_slot(1, spark)
	partial = controller.preview(spark, player, true)
	check(partial.components.size() == 2 and partial.cost == 32, "Joint release duplicated the partial boon surcharge")
	context = CastContext.simple(player, Vector2.RIGHT, spark)
	context.empower = true
	check(sm.use_source("slot_1", player, context), "Joint partial release rejected")
	controller.tick(.4)
	check(is_equal_approx(buffs.capture_status("ancestral_ward").remaining, snapshot.remaining * .5), "Joint release halved the same boon multiple times")
	check(not buffs.consume_duration("missing"), "Partial consumption accepted an absent status")
	buffs.apply_buff(sm.pool.get_skill("soul_harvest").buff_resource)
	check(not buffs.consume_duration("soul_charge"), "Equipment partially consumed a soul preparation")
	await fixture.close()
	if errors.is_empty(): print("Partial boons passed: retained/full/half, source, repeated expenditure, damage, shape, deduplication and atomic rollback")
	quit(0 if errors.is_empty() else 1)
