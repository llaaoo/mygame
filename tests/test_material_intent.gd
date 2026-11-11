extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
class Reject extends SkillExecutor:
	func execute(_skill: SkillData, _ctx: CastContext) -> bool: return false
var errors: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func _init() -> void: call_deferred("run")
func run() -> void:
	var fixture := Fixture.new(self)
	var game := await fixture.boot(true)
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(false)
	var player := game.player
	var sm := player.skill_manager
	sm.restrict_actions = false
	var c := sm.combinations
	var supplies := c.supplies
	var water := sm.pool.get_skill("water_call")
	sm.equip_slot(0, water)
	supplies.grant({"frost_salt": 4, "resin": 2})
	supplies.configure("water_call", "frost_salt")
	var before := supplies.serialize()
	for i in range(10): c.preview(water, player)
	check(before == supplies.serialize(), "Preview consumed/cleared intent")
	check(sm.use_slot(0, player, Vector2.RIGHT), "Material action rejected")
	c.cancel()
	check(before == supplies.serialize(), "Cancellation discarded unconsumed material choice")
	c.tick(.5)
	var original := sm.executor
	var reject := Reject.new()
	sm.add_child(reject)
	sm.executor = reject
	check(sm.use_slot(0, player, Vector2.RIGHT), "Rollback probe rejected")
	c.tick(1)
	check(supplies.serialize() == before, "Effect rejection lost choice or inventory")
	sm.executor = original
	reject.queue_free()
	c.tick(2)
	check(sm.use_slot(0, player, Vector2.RIGHT), "Single use action rejected")
	c.tick(1)
	check(supplies.count("frost_salt") == 3 and not supplies.selected.has("water_call"), "Successful compatible use did not clear choice once")
	check(c.preview(water, player).material_costs.is_empty(), "Next action reused old choice")
	supplies.configure("ignite", "resin")
	var spark := sm.pool.get_skill("ignite")
	sm.equip_hand("right", spark)
	c.tick(2)
	check(sm.use_hand("right", player, Vector2.RIGHT), "Incompatible ordinary spark rejected")
	c.tick(1)
	check(supplies.selected.get("ignite") == "resin" and supplies.count("resin") == 2, "Incompatible action consumed/discarded reagent")
	var result := sm.pool.get_skill("fireball")
	sm.equip_slot(1, result)
	check(sm.get_slot(1) == null and not c.start(result, player, CastContext.simple(player, Vector2.RIGHT, result), "slot_1"), "Combination result bypassed input guards")
	sm.restore_skill_state({"slot_1": {"skill_id": "fireball", "upgrades": {}}})
	check(sm.get_slot(1) == null, "Result equipped through disk loadout")
	check(not c.preview(result, player).ready, "Result preview advertised direct casting")
	check(SaveManager.instance.save_game(2), "Intent save failed")
	var saved := game.progress.casting_supplies
	check(saved.selected.is_empty() and supplies.selected.get("ignite") == "resin", "Saving either persisted choice or cleared live choice")
	game._change_region("yard")
	check(supplies.selected.is_empty(), "Region change kept selection")
	var migration := CastingSupplies.new()
	migration.restore({"amounts": {"resin": 2}, "selected": {"ignite": "resin"}})
	check(migration.discarded_legacy_selection and migration.selected.is_empty() and migration.count("resin") == 2, "Legacy selection migration changed inventory")
	await fixture.close()
	if errors.is_empty(): print("Material intent passed: pure preview, cancel/reject rollback, single-use and incompatible retention, result guards, transient disk/region intent and legacy migration")
	quit(0 if errors.is_empty() else 1)
