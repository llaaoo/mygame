extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []

class Reject extends SkillExecutor:
	func execute(_skill: SkillData, _context: CastContext) -> bool:
		return false

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot()
	_check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(false)
	var player := game.player
	var casting := player.casting
	var sm := player.skill_manager
	var mana := player.mana_component
	# Explicit sandbox capacity preserves the 100-MP pulse/rollback budget.
	mana.max_mp = 100
	player.global_position = Vector2(12000, 12000)
	sm.restrict_actions = false
	var channel := sm.pool.get_skill("shadow_bolt").duplicate(true) as SkillData
	channel.cast_type = "channel"
	channel.channel_tick_interval = 0.1
	channel.channel_mp_per_sec = 2.5
	channel.required_material = "resin"
	channel.material_amount = 1
	sm.equip_slot(1, channel)
	var supplies := sm.combinations.supplies
	supplies.grant({"resin": 30})
	var pulses := [0]
	sm.skill_used.connect(func(_source, _skill): pulses[0] += 1)
	for deltas in [[1.0], [0.2, 0.3, 0.5]]:
		mana.mp = 100
		pulses[0] = 0
		var initial := supplies.count("resin")
		casting._begin_channel("slot_1", sm.get_slot(1).data)
		for delta in deltas:
			casting.tick(delta)
		_check(pulses[0] == 10 and mana.mp == 97 and supplies.count("resin") == initial - 10, "Channel lost fractional MP, skipped large-delta pulses or bypassed materials")
		casting._cancel_channel()

	var equipment: EquipmentManager = player.get_node("EquipmentManager")
	var focus := EquipmentData.new()
	focus.slot_type = EquipmentData.SlotType.FEET
	focus.combat_modifiers = {"mana_cost.all": -0.5}
	equipment.equip(focus)
	mana.mp = 100
	casting._begin_channel("slot_1", sm.get_slot(1).data)
	casting.tick(1.0)
	_check(mana.mp == 98, "Channel applied cost modifiers after integer rounding")
	casting._cancel_channel()
	equipment.clear_all()
	supplies.grant({"resin": 3})

	var original := sm.executor
	var reject := Reject.new()
	sm.add_child(reject)
	sm.executor = reject
	mana.mp = 100
	var before := supplies.count("resin")
	casting._begin_channel("slot_1", sm.get_slot(1).data)
	casting.tick(0.1)
	_check(mana.mp == 100 and supplies.count("resin") == before and casting._channeling_source.is_empty(), "Rejected channel pulse consumed resources or did not stop")
	sm.executor = original
	reject.queue_free()

	var charged := sm.pool.get_skill("charged_fireball")
	sm.equip_slot(0, charged)
	casting._begin_charge("slot_0", sm.get_slot(0).data)
	casting.aiming_sources["slot_0"] = true
	casting.tick(charged.charge_duration * 0.5)
	var release := Action.cast("slot_1", Vector2.RIGHT, player)
	release.params.release = true
	release.cast_context = CastContext.simple(player, Vector2.RIGHT, sm.get_slot(1).data)
	player.resolve_action(release)
	_check(casting._charging_source == "slot_0" and is_equal_approx(casting._charge_power, 0.5), "Releasing another source consumed charge")
	casting.cancel_all()

	# Staging a summon must not register it or emit facts if the action aborts.
	var manager: SummonManager = player.get_node("SummonManager")
	var summon := sm.pool.get_skill("summon_skeleton")
	var context := CastContext.simple(player, Vector2.RIGHT, summon)
	context.batch = SkillExecutionBatch.new()
	var notices := [0]
	manager.summons_changed.connect(func(): notices[0] += 1)
	_check(sm.executor.execute(summon, context), "Summon preparation failed")
	_check(manager.active_summons.is_empty() and notices[0] == 0, "Staged summon became visible before commit")
	context.batch.abort()
	_check(manager.active_summons.is_empty() and notices[0] == 0, "Aborted summon changed manager state")
	context = CastContext.simple(player, Vector2.RIGHT, summon)
	context.batch = SkillExecutionBatch.new()
	_check(sm.executor.execute(summon, context), "Summon retry failed")
	sm.executor.commit_batch(context.batch)
	await process_frame
	_check(manager.active_summons.size() == 1 and notices[0] == 1 and manager.active_summons[0].get_parent() == game.region_root, "Committed summon did not activate once in its region")
	var entity := manager.active_summons[0]
	entity.queue_free()
	for i in range(3): await process_frame
	_check(manager.active_summons.is_empty(), "Direct summon removal left manager registration")
	# Accepted, detached effects still belong to the executor until they enter a live region.
	var pending_context := CastContext.simple(player, Vector2.RIGHT, summon)
	pending_context.batch = SkillExecutionBatch.new()
	_check(sm.executor.execute(summon, pending_context), "Pending summon preparation failed")
	sm.executor.commit_batch(pending_context.batch)
	var pending_summon := manager.active_summons[0]
	var storm := sm.pool.get_skill("flame_storm")
	var storm_context := CastContext.simple(player, Vector2.RIGHT, storm)
	_check(sm.executor.execute(storm, storm_context), "Pending area effect failed")
	game._change_region("yard")
	_check(not is_instance_valid(pending_summon) and manager.active_summons.is_empty() and sm.executor._pending_nodes.is_empty(), "Immediate travel leaked an accepted detached effect/registration")
	await fixture.close()
	if failures.is_empty():
		print("Player components passed: channel time/cost/material/rollback, charge source and staged summon lifecycle")
	quit(0 if failures.is_empty() else 1)
