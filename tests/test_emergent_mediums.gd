extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var failures: Array[String] = []
var game: MVPGame
var player: Player
var sm: SkillManager
var controller: ConditionalCastController
var surfaces: SurfaceManager

class RejectingExecutor extends SkillExecutor:
	func execute(_skill: SkillData, _context: CastContext) -> bool:
		return false

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / 64), floori(point.y / 64))

func _field(type: String) -> FireSigil:
	var field := FireSigil.new()
	field.field_type = type
	field.caster = player
	game.region_root.add_child(field)
	field.global_position = player.global_position
	controller.fields.append(field)
	controller.field = field
	return field

func _context(point: Vector2, empower: bool = false) -> CastContext:
	var context := CastContext.at_position(player, point, sm.get_slot(0).data)
	context.empower = empower
	return context

func _cast(point: Vector2, empower: bool = false) -> void:
	controller.cooldowns.clear()
	_check(sm.use_source("slot_0", player, _context(point, empower)), "Medium cast did not start: " + controller.last_message)
	controller.tick(1)
	for i in range(3): await process_frame

func _run() -> void:
	var fixture := Fixture.new(self)
	game = await fixture.boot()
	_check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(false)
	var sim := GameRuntime.instance.get_simulation_runtime()
	surfaces = sim.get_surface_manager()
	player = game.player
	player.global_position = Vector2(20000, 20000)
	player.mana_component.max_mp = 1000
	player.mana_component.mp = 1000
	sm = player.skill_manager
	sm.restrict_actions = false
	controller = sm.combinations
	controller.allow_layered_fields = true
	var supplies := controller.supplies
	supplies.grant({"frost_salt": 20, "storm_dust": 20, "venom_extract": 20})
	var water := sm.pool.get_skill("water_call")
	var counts := [game.catalog.actions.size(), game.catalog.spell_rules.size(), game.catalog.equipment.size(), supplies.catalog.size()]
	sm.equip_slot(0, water)
	var point := player.global_position + Vector2(96, 0)
	# All variants retain one action identity and derive their terrain from the shared rules.
	for spec in [["frost_salt", "frozen", 7], ["storm_dust", "electrified", 9], ["venom_extract", "poisoned", 8]]:
		supplies.configure("water_call", spec[0])
		var mana := player.mana_component.mp
		var count := supplies.count(spec[0])
		var plan := controller.build_plan(water, player)
		_check(plan.skill.get_id() == water.get_id() and plan.skill.damage == 0 and plan.skill.damage_scaling == 0 and plan.cost == spec[2], "Material manufactured a new damage spell or charged incorrectly")
		_check(surfaces.project_state("wet", plan.skill.surface_payload_tags) == spec[1] and SurfaceManager.surface_title(spec[1]) in plan.effect_label, "Medium preview disagrees with the rules")
		await _cast(point)
		_check(surfaces.get_surface(_cell(point)).state == spec[1] and supplies.count(spec[0]) == count - 1 and player.mana_component.mp == mana - int(spec[2]), "Actual material terrain/cost diverged from preview")
	_check(water.tags == ["water", "aoe"] and water.surface_payload_tags.is_empty() and water.aoe_visual.radius == 105 and water.aoe_visual.color == Color(0.15, 0.5, 0.9, 0.6), "Material or preview mutated the shared water definition")
	var home := player.global_position
	player.global_position = point
	surfaces.force_set_surface(_cell(point), "electrified", 5)
	surfaces.tick_entity_surface()
	_check((player.get_node("BuffManager") as BuffManager).has_buff("shocked"), "Player was exempt from the conductive water they created")
	(player.get_node("BuffManager") as BuffManager).clear_all()
	player.global_position = home
	# Property matching works with a different identity; BUFF actions cannot match it.
	var other := water.create_runtime_variant()
	other.id = "test_other_water"
	_check(supplies.catalog.frost_salt.supports(other.id, other.id, other), "Material selection still depends on the named action")
	other.skill_type = SkillData.SkillType.BUFF
	_check(not supplies.catalog.frost_salt.supports(other.id, other.id, other), "Material property selector ignored delivery type")
	# Surface poison must not be removed by its own water hit subscriber.
	supplies.configure("water_call", "venom_extract")
	var poison_water: SkillData = supplies.plan(water, water).skill
	var buffs := player.get_node("BuffManager") as BuffManager
	buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	CombatExecutor.report_hit(player, player, 0, player.global_position, poison_water, poison_water.tags)
	_check(buffs.has_buff("poison"), "Poison-bearing water washed away its own poison")
	buffs.clear_all()
	# A utility spell only spends a boon when it gains applicable shape/medium changes.
	supplies.configure("water_call", "frost_salt")
	buffs.apply_buff(load("res://gameplay/abilities/data/ancestral_ward_result.tres").buff_resource)
	_check(controller.build_plan(water, player, true).consumed_boons.is_empty(), "Utility water spent a damage-only boon")
	buffs.apply_buff(load("res://gameplay/abilities/data/frost_stride_result.tres").buff_resource)
	var expanded := controller.build_plan(water, player, true)
	_check(expanded.consumed_boons.has("霜行") and expanded.skill.aoe_visual.radius == 171 and expanded.cost == 10, "Material tags did not enable the existing frost boon's area tradeoff")
	await _cast(point, true)
	_check(not buffs.has_buff("frost_stride") and buffs.has_buff("ancestral_ward"), "Utility release consumed an inapplicable boon or retained the spent one")
	buffs.clear_all()
	# Equipment enables a different relationship to existing fields, on explicit request.
	var manager := player.get_node("EquipmentManager") as EquipmentManager
	manager.equip(game.catalog.equipment.keeper_ring)
	var fire := _field("fire")
	supplies.configure("water_call", "venom_extract")
	var normal := controller.build_plan(water, player)
	var infused := controller.build_plan(water, player, true)
	_check(normal.infusions.is_empty() and normal.cost == 9 and infused.cost == 12 and infused.infusions.size() == 1 and infused.skill.tags == normal.skill.tags and infused.skill.surface_payload_tags == ["poison", "fire"], "Equipment infusion was automatic, changed hit tags or charged incorrectly")
	_check(infused.effect_label.contains("水域→毒地→燃烧地面") and not infused.components[0].anchor_to_field, "Ordered transformation or ground anchor missing from plan")
	await _cast(point, true)
	_check(fire.charges == 1 and surfaces.get_surface(_cell(point)).state == "burning", "Infusion did not consume exactly one field charge at the requested point")
	var found := false
	for child in game.region_root.get_children():
		if child is PersistentAOE and child.global_position.is_equal_approx(point) and child._skill.surface_payload_tags == ["poison", "fire"]: found = true
	_check(found, "Infusion moved the effect to the borrowed field")
	# Newest *reactive* field wins. Unreactive fields are free and do not hide valid ones.
	var frost := _field("frost")
	var storm := _field("storm")
	supplies.configure("water_call", "frost_salt")
	infused = controller.build_plan(water, player, true)
	_check(infused.field == fire and infused.skill.surface_payload_tags == ["ice", "fire"] and infused.effect_label.contains("水域→冰面→水域"), "Unreactive newer fields hid the older meaningful thaw interaction")
	fire.global_position += Vector2(500, 0)
	var unchanged := controller.build_plan(water, player, true)
	_check(unchanged.infusions.is_empty() and unchanged.field == null and unchanged.cost == controller.build_plan(water, player).cost and frost.charges == 2 and storm.charges == 2, "Unreactive fields charged an infusion surcharge or consumed a charge")
	fire.global_position -= Vector2(500, 0)
	supplies.configure("water_call", "")
	_check(controller.build_plan(water, player, true).field == storm, "Infusion selection did not prefer the newest reactive field")
	# Rejected execution returns MP, material and field charge without painting terrain.
	supplies.configure("water_call", "venom_extract")
	infused = controller.build_plan(water, player, true)
	var selected := infused.field
	var charges := selected.charges
	var mana := player.mana_component.mp
	var venom := supplies.count("venom_extract")
	var executor := sm.executor
	var reject := RejectingExecutor.new()
	sm.add_child(reject)
	sm.executor = reject
	point += Vector2(0, 64)
	surfaces.force_set_surface(_cell(point), "dry", 12)
	await _cast(point, true)
	_check(player.mana_component.mp == mana and supplies.count("venom_extract") == venom and selected.charges == charges and surfaces.get_surface(_cell(point)).state == "dry", "Rejected infusion leaked resources or world effects")
	sm.executor = executor
	reject.queue_free()
	# Moving out of the accepted field cancels rather than silently casting another variant.
	controller.cooldowns.clear()
	_check(sm.use_source("slot_0", player, _context(point, true)), "Revalidation cast did not start")
	player.global_position += Vector2(500, 0)
	controller.tick(1)
	_check(controller.pending.is_empty() and player.mana_component.mp == mana and supplies.count("venom_extract") == venom and selected.charges == charges, "Lost infusion conditions silently downgraded or charged the cast")
	player.global_position -= Vector2(500, 0)
	controller.reset_session()
	# An active combination already using a field has priority over optional borrowing.
	# Temporary definitions exercise extension without adding authored spell entries.
	var action := water.create_runtime_variant()
	action.id = "test_layered_medium"
	var state_rule := SpellCombinationRule.new()
	state_rule.id = "test_state_medium"
	state_rule.trigger_action_id = action.id
	state_rule.required_caster_status = "echo_ready"
	state_rule.result_skill = water
	var field_rule := SpellCombinationRule.new()
	field_rule.id = "test_field_medium"
	field_rule.trigger_action_id = action.id
	field_rule.required_field_type = "fire"
	field_rule.result_skill = water
	controller.rules.append_array([state_rule, field_rule])
	controller.rule_index.rebuild(controller.rules)
	controller.learned_rules[state_rule.id] = true
	controller.learned_rules[field_rule.id] = true
	buffs.apply_buff(load("res://gameplay/abilities/data/echo_mark_data.tres").buff_resource)
	fire = _field("fire")
	var layered := controller.build_plan(action, player, true)
	_check(layered.components.size() == 2 and layered.infusions.is_empty() and layered.components[0].field == null and layered.components[1].field == fire, "Optional infusion claimed a field already used by an active combination")
	controller.rules.erase(state_rule)
	controller.rules.erase(field_rule)
	controller.rule_index.rebuild(controller.rules)
	controller.learned_rules.erase(state_rule.id)
	controller.learned_rules.erase(field_rule.id)
	buffs.clear_all()
	controller.reset_session()
	# Ordinary and prepared execution share unique charge transaction ids, including retries.
	var ordinary := water.create_runtime_variant()
	ordinary.conditional_cast = false
	ordinary.cooldown = 0
	sm.equip_slot(0, ordinary)
	supplies.configure("water_call", "")
	storm = _field("storm")
	for i in range(2):
		sm.tick(1)
		_check(sm.use_source("slot_0", player, _context(point, true)), "Successive ordinary infusion reused a field transaction id")
		for j in range(3): await process_frame
	_check(storm.charges == 0 and surfaces.get_surface(_cell(point)).state == "electrified", "Ordinary casts failed to share the medium/charge contract")
	# Projectile impact delivery uses the same medium pipeline, without another pair table.
	var projectile_skill := water.create_runtime_variant()
	projectile_skill.creates_surface = ""
	projectile_skill.impact_surface = "wet"
	projectile_skill.skill_type = SkillData.SkillType.PROJECTILE
	projectile_skill = supplies.catalog.frost_salt.modify(projectile_skill)
	var projectile := load("res://gameplay/abilities/archetypes/linear_projectile.tscn").instantiate() as Projectile
	projectile.set_meta("skill_data", projectile_skill)
	projectile.setup(projectile_skill, player, Vector2.RIGHT)
	game.region_root.add_child(projectile)
	projectile.global_position = point
	projectile._apply_impact_surface()
	_check(surfaces.get_surface(_cell(point)).state == "frozen", "Projectile impact bypassed material medium transformations")
	projectile.queue_free()
	# One area shares one conduction budget across branching pools; dry gaps stop it.
	sim.clear_region()
	var origin := Vector2i(500, 500)
	for x in range(-20, 21):
		for y in range(-1, 2): surfaces.force_set_surface(origin + Vector2i(x, y), "wet", 12)
	surfaces.force_set_surface(origin + Vector2i(0, 3), "wet", 12)
	var world_point := Vector2(origin * 64) + Vector2(32, 32)
	surfaces.apply_area(world_point, 80, ["water", "lightning"], "test", "wet", 12, false, ["lightning"])
	var electric := 0
	for cell: Vector2i in sim.surface_cells():
		if surfaces.get_surface(cell).state == "electrified": electric += 1
	_check(electric >= 5 and electric <= 53 and surfaces.get_surface(origin + Vector2i(0, 3)).state == "wet", "Area conduction multiplied its budget or crossed dry ground")
	_check(counts == [game.catalog.actions.size(), game.catalog.spell_rules.size(), game.catalog.equipment.size(), supplies.catalog.size()], "Emergent extension inflated authored catalogs")
	await fixture.close()
	if failures.is_empty(): print("Emergent mediums passed: property materials, ordered world rules, applicable boons, equipment infusion, real ground/projectile delivery, atomic rollback and bounded propagation")
	quit(0 if failures.is_empty() else 1)
