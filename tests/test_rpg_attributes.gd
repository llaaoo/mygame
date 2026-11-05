extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
class ExtraHazard extends TriggeredEffect:
	func _execute(event: CombatEvent) -> void:
		CombatExecutor.report_bonus_damage(event.source, event.target, 10, event.skill, ["dot", "poison"])
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func run() -> void:
	var fixture := Fixture.new(self)
	var game := await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	var player := game.player
	var stats := player.stats_component
	var buffs := player.get_node("BuffManager") as BuffManager
	var sm := player.skill_manager
	var controller := sm.combinations
	sm.restrict_actions = false
	check(player.health_component.max_hp == 100 and player.mana_component.max_mp == 60 and stats.preparation_multiplier == 1 and stats.hazard_damage_multiplier == 1, "Baseline attributes changed old costs/caps")
	var base := stats.primary_values()
	var projected := stats.derived_values({"agility": 14, "endurance": 20})
	check(is_equal_approx(projected.preparation_multiplier, .94) and is_equal_approx(projected.hazard_damage_multiplier, .8) and stats.primary_values() == base, "Attribute preview mutated character or used inconsistent rules")
	var limits := stats.derived_values({"agility": 100, "endurance": 100})
	check(is_equal_approx(limits.preparation_multiplier, .7) and is_equal_approx(limits.hazard_damage_multiplier, .6), "Derived safety caps failed")
	stats.attribute_points = 1
	check(not stats.spend_attribute_point("missing") and stats.attribute_points == 1 and not stats.modify_stat("missing", 5), "Unknown attribute spent points or mutated state")
	check(stats.spend_attribute_point("agility") and stats.attribute_points == 0 and stats.agility == 11 and is_equal_approx(stats.preparation_multiplier, .985), "Training did not atomically spend and update derived values")
	stats.modify_stat("agility", -1)
	stats.attribute_points = 3
	var points_seen: Array[int] = []
	stats.stat_changed.connect(func(_key: String, _value: int): points_seen.append(stats.attribute_points))
	check(stats.spend_attribute_point("strength") and points_seen.back() == 2, "Observers saw points before spending")
	stats.modify_stat("strength", -1)
	# The same effective primary values feed Buffs, UI, casting and task checks.
	var agile := Buff.new()
	agile.buff_id = "test.agile"
	agile.status_id = "test.agile"
	agile.duration = 5
	agile.stat_modifiers = {"agility": 4, "strength": 4}
	var action := sm.pool.get_skill("water_call")
	sm.equip_slot(0, action)
	var ordinary := controller.preview(action, player)
	check(sm.use_slot(0, player, Vector2.RIGHT), "Attribute rollback probe failed to prepare")
	var mana := player.mana_component.mp
	var supplies := controller.supplies.serialize()
	buffs.apply_buff(agile, player)
	check(stats.effective_stat("agility") == 14 and stats.meets_requirements({"strength": 14}) and not stats.meets_requirements({"strength": 14, "intelligence": 14}) and not stats.meets_requirements({"bad": 1}), "Effective attribute checks ignored Buffs or AND semantics")
	check("AGI 14" in game.get_node("HUDLayer").stats_label.text, "HUD disagreed with effective Buff attributes")
	controller.tick(1)
	check(controller.pending.is_empty() and player.mana_component.mp == mana and supplies == controller.supplies.serialize() and "未扣费" in controller.last_message, "Attribute change during preparation leaked resources")
	controller.tick(.4)
	var faster := controller.preview(action, player)
	check(is_equal_approx(faster.preparation, ordinary.preparation * .94) and "敏捷14" in controller.describe_plan(faster), "Preparation and its explanation disagree with agility")
	buffs.tick(6)
	check(stats.effective_stat("agility") == 10 and stats.preparation_multiplier == 1 and not stats.meets_requirements({"strength": 14}), "Expired attribute Buff kept its task/cast benefits")
	var equipment := player.get_node("EquipmentManager") as EquipmentManager
	var item := EquipmentData.new()
	item.id = "test.intelligence_ring"
	item.slot_type = EquipmentData.SlotType.RING
	item.stat_modifiers = {"intelligence": 4}
	equipment.equip(item)
	check(stats.intelligence == 10 and stats.effective_stat("intelligence") == 14 and stats.meets_requirements({"intelligence": 14}) and stats.magic_damage == 28, "Equipment primary attributes diverged from Buff/check/derived queries")
	equipment.unequip(EquipmentData.SlotType.RING)
	check(stats.effective_stat("intelligence") == 10 and stats.max_mana == 60, "Unequipped primary attributes remained effective")
	# Incoming hazard mitigation is sampled once and shared with bonus damage.
	stats.modify_stat("endurance", 10)
	player.health_component.invincible = false
	var hit := CombatExecutor.report_hit(null, player, 10, player.position, null, ["melee"])
	check(hit.damage_dealt == 10, "Endurance incorrectly reduced ordinary melee")
	for tags in [["dot", "poison"], ["environment"], ["trap"]]:
		player.health_component.invincible = false
		hit = CombatExecutor.report_hit(null, player, 10, player.position, null, tags)
		check(hit.damage_dealt == 8, "Endurance failed to reduce hazardous delivery: " + str(tags))
	var bonus := ExtraHazard.new()
	bonus.trigger_type = CombatEvent.Type.ON_HIT
	bonus.scope_source = "global"
	bonus.register()
	player.health_component.invincible = false
	var before := player.health_component.hp
	CombatExecutor.report_hit(null, player, 10, player.position, null, ["dot", "poison"])
	check(before - player.health_component.hp == 16, "Hazard mitigation was duplicated or missing on bonus damage")
	bonus.unregister()
	stats.modify_stat("endurance", -10)
	# Optional submissions never fabricate puzzle discoveries or bypass verification.
	var quest: ExplorationQuestData
	for candidate in game.quests:
		if candidate.id == "field_research": quest = candidate
	for region in ["archive", "drain", "cistern"]:
		game.progress.cleared[region] = true
		game.progress.claims["field." + region + "_observation"] = true
	check(not quest.is_complete(game.progress) and not game.progress_service.claim_quest(quest, "analysis"), "Incomplete attributes bypassed the normal task route")
	stats.modify_stat("intelligence", 3)
	check(not game.progress_service.claim_quest(quest, "analysis") and not game.progress_service.claim_quest(quest, "made_up"), "Threshold edge or unknown task approach accepted")
	var insight := Buff.new()
	insight.status_id = "test.insight"
	insight.duration = 1
	insight.stat_modifiers = {"intelligence": 1}
	buffs.apply_buff(insight, player)
	check(quest.can_claim(game.progress, stats, "analysis"), "Temporary attribute preparation could not qualify a task approach")
	buffs.tick(1.1)
	check(not game.progress_service.claim_quest(quest, "analysis"), "Submission trusted an expired attribute preview")
	stats.modify_stat("intelligence", 1)
	check(quest.has_available_approach(game.progress, stats), "Qualified alternate task route remained hidden")
	var points := stats.attribute_points
	var verified := game.progress.verified_reactions.duplicate()
	check(game.progress_service.claim_quest(quest, "analysis") and stats.attribute_points == points + 1 and game.progress.choices["quest.field_research"] == "analysis", "Attribute route did not award/persist its actual choice")
	check(not game.progress_service.claim_quest(quest) and not game.progress_service.claim_quest(quest, "analysis") and stats.attribute_points == points + 1, "Alternate and normal routes awarded the same task twice")
	for key in ["magic.charged_crystal", "magic.thermal_cache", "magic.waterworks_conductor"]: check(not game.progress.claims.has(key), "Task approach falsely opened a mechanism")
	check(verified == game.progress.verified_reactions, "Task approach fabricated a verified elemental reaction")
	var other := ExplorationProgress.new()
	for region in ["archive", "drain", "cistern"]: other.cleared[region] = true
	for key in ["magic.charged_crystal", "magic.thermal_cache", "magic.waterworks_conductor"]: other.claims[key] = true
	stats.modify_stat("strength", 4)
	check(quest.can_claim(other, stats, "inspection") and not quest.is_complete(other), "Strength-based inspection did not replace the written observations")
	for key in quest.required_claims: other.claims[key] = true
	stats.modify_stat("strength", -4)
	stats.modify_stat("intelligence", -4)
	check(quest.can_claim(other, stats), "Original full-report route acquired an attribute gate")
	stats.modify_stat("intelligence", 4)
	game.presenter._show_training()
	var text := ""
	for label in game.ui.modal.find_children("*", "RichTextLabel", true, false): text += label.text
	check("下一点基础派生变化" in text and "属性准备" in text and "%d" not in text, "Training UI omitted consequences or failed formatting")
	game.ui.close_modal()
	check(SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Attribute task save failed")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	check(game.player.stats_component.intelligence == 14 and game.progress.choices["quest.field_research"] == "analysis" and game.progress.claims.has("quest.field_research"), "Disk restore lost trained attributes or task approach")
	await fixture.close()
	if errors.is_empty(): print("RPG attributes passed: pure projections, atomic training, effective checks, preparation rollback, hazard/bonus semantics, alternate tasks, original routes and disk restore")
	quit(0 if errors.is_empty() else 1)
