extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func _run() -> void:
	var fixture := Fixture.new(self)
	var game := await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	var text := game.presenter.journal_text()
	check(not text.contains("前哨锅位") and not text.contains("排水回廊检修前哨") and not text.contains("旧伙房锅"), "Journal revealed undiscovered supply facilities")
	game.trial_recorder.show_page()
	var experiment: RichTextLabel = game.ui._modal_panel.find_child("BodyScroll", true, false).get_child(0)
	check(not experiment.text.contains("蓄水机房") and not experiment.text.contains("导能晶簇"), "Experiment page revealed undiscovered locations or solutions")
	game.ui.close_modal()
	var station: ExplorationInteractable
	for node in game.region_root.get_children():
		if node.has_meta("survival_station"):
			station = node
			break
	game.player.position = station.position
	var spec: SurvivalStationData = station.get_meta("survival_station")
	game.survival.inspect(station, spec)
	check(game.presenter.journal_text().contains(spec.title) and game.progress.claims.has("seen." + spec.id), "Inspected supply was not recorded")
	game.player.field_work.close_panel()
	game.survival.needs.meal = "broth"
	game.survival.needs.meal_remaining = 120
	game.survival.needs.water_remaining = 80
	game.survival.needs.tea_remaining = 50
	check(game.survival.timers_line() == "食物120s · 饮水80s · 茶50s", "HUD did not show independent effect timers")
	game.player.skill_manager.combinations.supplies.grant({"ration": 1})
	game.survival.show_page()
	var body: RichTextLabel = game.ui._modal_panel.find_child("BodyScroll", true, false).get_child(0)
	check(not body.text.contains("每15秒下降") and body.text.contains("当前需求稳定") and body.text.contains("饱食+45"), "Supply page lost concise current needs/food benefits")
	game.survival.show_rules()
	body = game.ui._modal_panel.find_child("BodyScroll", true, false).get_child(0)
	check(body.text.contains("每15秒下降"), "Detailed rules no longer accessible")
	game.ui.close_modal()
	var inventory := game.player.skill_manager.combinations.supplies.serialize()
	var actions := game.player.skill_manager.serialize_skill_state()
	var position := game.player.position
	check(game.trial_recorder.start("导电布场"), "Trial label failed")
	check(inventory == game.player.skill_manager.combinations.supplies.serialize() and actions == game.player.skill_manager.serialize_skill_state() and position == game.player.position, "Measurement label applied a build or preparation")
	game.trial_recorder.finish()
	game._save_progress()
	await fixture.close()
	game = await fixture.boot(true)
	check(game.progress.claims.has("seen." + spec.id) and game.presenter.journal_text().contains(spec.title), "Discovered supply not preserved on disk")
	await fixture.close()
	if errors.is_empty(): print("Expedition feedback passed: no facility spoilers, actual discovery persistence, independent timers, concise/details pages and inert trial labels")
	quit(0 if errors.is_empty() else 1)
