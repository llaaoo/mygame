extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
var game: MVPGame
var player: Player
var controller: ConditionalCastController
var buffs: BuffManager
var supplies: CastingSupplies
var surfaces: SurfaceManager
var focus: SkillData
var cell: Vector2i
class RejectingExecutor extends SkillExecutor:
	func execute(_skill: SkillData, _context: CastContext) -> bool: return false

func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func reset() -> void:
	controller.reset_session()
	buffs.clear_all()
	supplies.configure("focus", "")
	player.global_position = Vector2(24032, 24032)
	player.mana_component.mp = 1000
	cell = SurfaceManager.cell_at(player.global_position)
	surfaces.force_set_surface(cell, "dry", 0)
func start(action: SkillData = null, empowered: bool = true) -> bool:
	if action == null: action = focus
	player.skill_manager.equip_slot(0, action)
	var context := CastContext.at_position(player, player.global_position, action)
	context.empower = empowered
	return player.skill_manager.use_source("slot_0", player, context)

func _run() -> void:
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	player = game.player
	player.mana_component.max_mp = 1000
	player.health_component.max_hp = 1000
	player.health_component.hp = 1000
	player.skill_manager.restrict_actions = false
	controller = player.skill_manager.combinations
	buffs = player.get_node("BuffManager")
	supplies = controller.supplies
	surfaces = GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	focus = player.skill_manager.pool.get_skill("focus")
	for rule in controller.rules: controller.learned_rules[rule.id] = true
	supplies.grant({"resin": 20, "frost_salt": 20, "storm_dust": 20, "venom_extract": 20, "ward_powder": 20})
	reset()
	var rows := [["fire", "burning", "ember_focus", 10], ["water", "wet", "flow_attunement", 8], ["frost", "frozen", "frost_stride", 10], ["lightning", "electrified", "static_focus", 10], ["poison", "poisoned", "venom_accord", 8]]
	for row in rows:
		reset()
		surfaces.force_set_surface(cell, row[1], 12, "source")
		surfaces.force_set_surface(cell + Vector2i.RIGHT, row[1], 12, "neighbor")
		var plan := controller.preview(focus, player, true)
		check(plan.rule_id == "terrain_" + row[0] + "_focus" and plan.cost == row[3], "Wrong terrain preparation: " + row[0])
		check(surfaces.get_surface(cell).state == row[1] and not game.progress.verified_reactions.has("prepare:" + plan.rule_id + ":surface"), "Preview consumed terrain or verified preparation")
		check(start(), "Terrain focus did not prepare: " + row[0])
		controller.tick(.41)
		check(buffs.has_buff(row[2]) and player.mana_component.mp == 1000 - row[3], "Terrain focus did not commit boon/cost: " + row[0])
		check(surfaces.get_surface(cell).state == "dry" and surfaces.get_surface(cell + Vector2i.RIGHT).state == row[1], "Terrain focus consumed more than its source cell")
		check(game.progress.verified_reactions.has("prepare:terrain_" + row[0] + "_focus:surface"), "Committed preparation did not enter knowledge")
	reset()
	surfaces.force_set_surface(cell, "wet", 12)
	check(controller.preview(focus, player).rule_id.is_empty() and controller.preview(focus, player).cost == 4, "Ordinary Focus changed")
	controller.learned_rules.erase("terrain_water_focus")
	check(controller.preview(focus, player, true).rule_id.is_empty(), "Unlearned terrain technique resolved")
	controller.learned_rules.terrain_water_focus = true
	# Prepared sources stay bound to their cell, phase and generation.
	for change in ["move", "phase", "expire", "remove_refill"]:
		reset()
		surfaces.force_set_surface(cell, "wet", 12, "original")
		check(start(), "Preparation invalidation setup failed")
		match change:
			"move": player.global_position += Vector2(64, 0)
			"phase": surfaces.force_set_surface(cell, "frozen", 12)
			"expire": surfaces.force_set_surface(cell, "dry", 0)
			"remove_refill":
				surfaces.force_set_surface(cell, "dry", 0)
				surfaces.force_set_surface(cell, "wet", 12)
		controller.tick(.41)
		check(controller.pending.is_empty() and not buffs.has_buff("flow_attunement") and player.mana_component.mp == 1000, "Stale terrain preparation committed: " + change)
	reset()
	surfaces.force_set_surface(cell, "wet", 12)
	check(start(), "Renewal setup failed")
	surfaces.force_set_surface(cell, "wet", 20, "valve")
	controller.tick(.41)
	check(buffs.has_buff("flow_attunement"), "Same-phase valve refill cancelled preparation")
	# Material selection overrides ambient terrain and is a preparation cost only.
	for row in [["resin", "ember_focus", 14], ["frost_salt", "frost_stride", 12], ["storm_dust", "static_focus", 14], ["venom_extract", "venom_accord", 11]]:
		reset()
		surfaces.force_set_surface(cell, "wet", 12)
		supplies.configure("focus", row[0])
		var count := supplies.count(row[0])
		var plan := controller.preview(focus, player, true)
		check(plan.skill.get_id() == row[1] and plan.cost == row[2] and plan.components[0].surface_state.is_empty(), "Selected material lost precedence over terrain")
		check(plan.skill == player.skill_manager.pool.get_skill(row[1]), "Preparation material incorrectly modified the buff result")
		check(controller.preview(focus, player).cost == 4, "Preparation material was charged for ordinary Focus")
		check(start(), "Material focus did not prepare")
		controller.tick(.41)
		check(buffs.has_buff(row[1]) and supplies.count(row[0]) == count - 1 and surfaces.get_surface(cell).state == "wet", "Material preparation consumed wrong source")
	reset()
	surfaces.force_set_surface(cell, "wet", 12)
	supplies.configure("focus", "resin")
	var resin := supplies.count("resin")
	supplies.amounts.resin = 0
	check(not start() and surfaces.get_surface(cell).state == "wet" and player.mana_component.mp == 1000, "Missing material silently fell back to terrain")
	supplies.amounts.resin = resin
	player.mana_component.mp = 1
	check(not start() and supplies.count("resin") == resin and surfaces.get_surface(cell).state == "wet", "Insufficient mana leaked resources")
	# Existing fields and imprint/soul combinations keep precedence.
	reset()
	surfaces.force_set_surface(cell, "wet", 12)
	supplies.configure("focus", "resin")
	var field := FireSigil.new()
	field.caster = player
	field.field_type = "frost"
	game.region_root.add_child(field)
	field.global_position = player.global_position
	controller.fields.append(field)
	controller.field = field
	check(controller.preview(focus, player, true).rule_id == "frost_sigil_focus" and controller.preview(focus, player, true).material_costs.is_empty(), "Terrain/material preparation overrode existing field")
	controller.clear_field()
	var echo := player.skill_manager.pool.get_skill("echo_mark")
	buffs.apply_buff(echo.buff_resource, player, echo)
	check(controller.preview(focus, player, true).rule_id == "echo_focus", "Terrain preparation overrode echo")
	# Late rejection restores exact terrain, an existing passive and all resource facts.
	reset()
	surfaces.force_set_surface(cell, "wet", 7.25, "rollback_source")
	var old_boon := player.skill_manager.pool.get_skill("ember_focus")
	buffs.apply_buff(old_boon.buff_resource, player, old_boon)
	var old_status := buffs.capture_status("ember_focus")
	var notices := [0, 0]
	buffs.buffs_changed.connect(func(): notices[0] += 1)
	player.mana_component.mp_changed.connect(func(_a, _b): notices[1] += 1)
	var original := player.skill_manager.executor
	var reject := RejectingExecutor.new()
	player.skill_manager.add_child(reject)
	player.skill_manager.executor = reject
	game.progress.verified_reactions.erase("prepare:terrain_water_focus:surface")
	check(start(), "Rejected source failed to prepare")
	controller.tick(.41)
	var restored := surfaces.get_surface(cell)
	check(restored.state == "wet" and restored.remaining == 7.25 and restored.source == "rollback_source", "Late rejection lost terrain lifetime/source")
	check(player.mana_component.mp == 1000 and buffs.capture_status("ember_focus").instance == old_status.instance and notices == [0, 0], "Rejected terrain preparation leaked resource facts/passive")
	check(not game.progress.verified_reactions.has("prepare:terrain_water_focus:surface"), "Rejected preparation awarded knowledge")
	player.skill_manager.executor = original
	reject.queue_free()
	# Water affinity spans liquid and frost; old frost affinity remains exact.
	reset()
	var flow := player.skill_manager.pool.get_skill("flow_attunement")
	buffs.apply_buff(flow.buff_resource, player, flow)
	var water := player.skill_manager.pool.get_skill("water_call")
	var bolt := player.skill_manager.pool.get_skill("frost_bolt")
	check(BoonSpellModifier.plan(water, player, false).retained.has("流息") and BoonSpellModifier.plan(bolt, player, false).retained.has("流息"), "Water family boon missed a water form/utility")
	check("ice" not in BoonSpellModifier.plan(water, player, false).skill.tags, "Water boon froze ordinary liquid")
	check(is_equal_approx(buffs.get_damage_taken_multiplier(), .9), "Flow defense missing")
	# A material payload survives until a later boon creates a projectile medium.
	var poison_bolt: SkillData = supplies.catalog.venom_extract.modify(bolt)
	var enhanced := BoonSpellModifier.plan(poison_bolt, player, true)
	check(enhanced.skill.impact_surface == "wet" and surfaces.project_state("wet", enhanced.skill.surface_payload_tags) == "poisoned", "Material payload disappeared before boon-created medium")
	check(bolt.impact_surface.is_empty() and bolt.surface_payload_tags.is_empty(), "Planning mutated authored frost bolt")
	# Poison defense is genuinely lost on full release; partial release retains current lifetime.
	reset()
	var accord := player.skill_manager.pool.get_skill("venom_accord")
	var poison := load("res://gameplay/abilities/data/poison.tres") as Buff
	buffs.apply_buff(poison)
	buffs.apply_buff(accord.buff_resource, player, accord)
	check(not buffs.has_buff("poison") and buffs.is_immune("poison"), "Poison accord failed to cleanse/protect")
	buffs.apply_buff(poison)
	check(not buffs.has_buff("poison") and not buffs.is_immune("burning"), "Poison protection blocked unrelated status or let poison through")
	var venom := player.skill_manager.pool.get_skill("venom_mist")
	check(start(venom), "Full poison release failed")
	controller.tick(.41)
	check(not buffs.is_immune("poison") and not buffs.has_buff("venom_accord"), "Full release kept poison immunity")
	for i in range(2): await process_frame
	surfaces.apply_surface_to(player)
	check(buffs.has_buff("poison"), "Full release's own poison terrain caused no risk")
	reset()
	var equipment := player.get_node("EquipmentManager") as EquipmentManager
	equipment.equip(game.catalog.equipment.cadence_gloves)
	buffs.apply_buff(accord.buff_resource, player, accord)
	buffs.tick(2)
	var remaining: float = buffs.capture_status("venom_accord").remaining
	check(start(venom), "Partial poison release failed")
	controller.tick(.41)
	check(is_equal_approx(buffs.capture_status("venom_accord").remaining, remaining * .5) and buffs.is_immune("poison") and player.mana_component.mp == 986, "Partial poison lifetime/immunity/cost incorrect")
	for i in range(2): await process_frame
	surfaces.apply_surface_to(player)
	check(not buffs.has_buff("poison"), "Partial release lost residual immunity")
	equipment.unequip(EquipmentData.SlotType.HANDS)
	# Ward powder extends environment preparation, but does not change its source.
	reset()
	surfaces.force_set_surface(cell, "wet", 12)
	supplies.configure("focus", "ward_powder")
	check(start(), "Ward-supported terrain preparation failed")
	controller.tick(.41)
	check(buffs.capture_status("flow_attunement").remaining == 12 and supplies.count("ward_powder") == 19 and player.mana_component.mp == 990, "Ward powder did not extend the new boon")
	# Backfill only newly attached techniques, never the rewards from claimed notes.
	var amounts := supplies.amounts.duplicate()
	game.progress.claims.material_handbook = true
	game.progress.spell_rules.erase("terrain_water_focus")
	game.progress_service._apply_knowledge()
	check(game.progress.spell_rules.has("terrain_water_focus") and supplies.amounts == amounts, "Old note reconciliation missed technique or duplicated materials")
	check("材料准备" in game.knowledge.text() or "树脂" in game.knowledge.text(), "Preparation observations were not readable")
	check(SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Attunement knowledge save failed")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	check(game.progress.spell_rules.has("terrain_water_focus") and game.progress.verified_reactions.has("prepare:terrain_poison_focus:material"), "Fresh disk restore lost techniques/verified source")
	await fixture.close()
	# Revisions remain bounded and do not repeat after clear.
	var scheduler := SurfaceScheduler.new()
	scheduler.set_surface(Vector2i.ZERO, "wet", 1)
	var old_revision := scheduler.revision(Vector2i.ZERO)
	scheduler.clear()
	for i in range(300): scheduler.set_surface(Vector2i(i, 0), "wet", 1)
	check(scheduler.active_count() == 256 and scheduler._versions.size() == 256 and scheduler.revision(Vector2i.ZERO) > old_revision, "Surface reservations escaped bounds or reused stale revision")
	scheduler.tick(2)
	check(scheduler._versions.is_empty() and scheduler.active_count() == 0, "Expired reservations leaked metadata")
	scheduler.free()
	if errors.is_empty(): print("Environment attunement passed: five sources, material substitution, phase reservations, rollback, water family, poison risk, partial release, backfill and saved observations")
	quit(0 if errors.is_empty() else 1)
