extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
class Target extends Node2D:
	func take_damage(amount: int) -> void: ($HealthComponent as HealthComponent).take_damage(amount)
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func _run() -> void:
	var fixture := Fixture.new(self)
	var game: MVPGame = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	var player := game.player
	player.global_position = Vector2(22000, 22000)
	var sm := player.skill_manager
	sm.restrict_actions = false
	var controller := sm.combinations
	var water := sm.pool.get_skill("water_call")
	check(game.progress.verified_reactions.is_empty() and "毒焰引爆" not in game.knowledge.text(), "Knowledge page spoiled undiscovered advanced reactions")
	for note in game.current_data.discoveries:
		if "施法材料手册" in note.title:
			check(game.progress_service.discover(note), "Material handbook could not grant clues")
	check(game.progress.element_clues.size() == 4 and game.progress.verified_reactions.is_empty(), "Clues were confused with actual verification")
	var equipment := player.get_node("EquipmentManager") as EquipmentManager
	equipment.equip(game.catalog.equipment.cadence_gloves)
	var frost := sm.pool.get_skill("frost_stride")
	(player.get_node("BuffManager") as BuffManager).apply_buff(frost.buff_resource)
	controller.supplies.configure("water_call", "frost_salt")
	var shifted := controller.preview(water, player, true)
	var normal := controller.preview(water, player)
	var kinds: Array[String] = []
	for step in shifted.explanation: kinds.append(step.kind)
	check("action" in kinds and "material" in kinds and "boon" in kinds and "effect" in kinds and "cost" in kinds, "Typed explanation lost transformation sources")
	var text := controller.describe_comparison(water, player, normal, shifted)
	check("普通施法" in text and "Shift施法" in text and "50%" in text and "半径171" in text and "实际命中" in text, "Comparison did not explain ordinary/Shift shape, spending and uncertainty")
	game.workshop.show_action(water)
	check(is_instance_valid(game.ui.modal) and paused, "Material comparison panel did not open")
	game.ui.close_modal()
	var surfaces := GameRuntime.instance.get_simulation_runtime().get_surface_manager()
	surfaces.project_state("wet", ["ice"])
	check(game.progress.verified_reactions.is_empty(), "Preview/query falsely awarded knowledge")
	var cell := SurfaceManager.cell_at(player.global_position)
	surfaces.force_set_surface(cell, "wet", 12)
	surfaces.apply_tags(cell, ["ice"], "test")
	check(game.progress.verified_reactions.has("surface:wet_ice") and "水域＋凝霜→冰面" in game.knowledge.text(), "Real local surface reaction did not record knowledge")
	var target := Target.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = 1000
	health.hp = 1000
	health.regen_rate = 0
	target.add_child(health)
	var buffs := BuffManager.new()
	buffs.name = "BuffManager"
	target.add_child(buffs)
	game.region_root.add_child(target)
	target.global_position = player.global_position + Vector2(40, 0)
	buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	var spark := sm.pool.get_skill("ignite")
	controller.describe_comparison(spark, player, null, null, target)
	check(not game.progress.verified_reactions.has("hit:toxic_ignition"), "Target prediction verified a reaction before contact")
	CombatExecutor.report_hit(player, target, 100, target.global_position, spark, spark.tags)
	check(game.progress.verified_reactions.has("hit:toxic_ignition") and "毒焰引爆" in game.knowledge.text(), "Actual hit reaction did not record its explanation")
	game.knowledge.show_page()
	check(is_instance_valid(game.ui.modal), "Element journal page failed")
	game.ui.close_modal()
	check(SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Knowledge save failed")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	check(game.progress.element_clues.size() == 4 and game.progress.verified_reactions.has("hit:toxic_ignition") and game.progress.verified_reactions.has("surface:wet_ice"), "Fresh disk restore lost distinct clues/verified knowledge")
	var progress := ExplorationProgress.new()
	check(not progress.validate_save_data({"verified_reactions": {"hit:melt": 1}}), "Malformed knowledge accepted")
	progress.deserialize_save_data({"claims": {}})
	check(progress.element_clues.is_empty() and progress.verified_reactions.is_empty(), "Legacy save did not default safely")
	progress.deserialize_save_data({"element_clues": {"ice": true}, "actions": {"ignite": true, "frost_sigil": true}, "spell_rules": {"frost_sigil_spark": true}, "verified_reactions": {"surface:wet_ice": true}})
	check(progress.element_clues == {"water": true} and progress.actions.has("frost_sigil") and progress.spell_rules.has("frost_sigil_spark") and progress.verified_reactions.has("surface:wet_ice"), "Legacy frost knowledge migration changed learned abilities or reaction identity")
	check(not progress.serialize_save_data().element_clues.has("ice"), "New saves kept frost as a separate core affinity")
	await fixture.close()
	if errors.is_empty(): print("Element knowledge passed: typed explanations, comparisons, clues vs observations, no preview spoilers, UI and fresh disk persistence")
	quit(0 if errors.is_empty() else 1)
