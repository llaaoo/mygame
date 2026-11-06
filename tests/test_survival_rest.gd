extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func run() -> void:
	var fixture := Fixture.new(self)
	var game := await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	var player := game.player
	var service := game.survival
	var work := player.field_work
	var rest: ExplorationInteractable
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.get_meta("survival_rest", false): rest = node
	check(rest != null, "Rest interaction missing")
	player.health_component.hp = 20
	player.mana_component.mp = 10
	game._change_region("camp")
	check(player.health_component.hp == 20 and player.mana_component.mp == 10, "Traveling to camp restored vitals without resting")
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.get_meta("survival_rest", false): rest = node
	service.needs.nutrition = 70
	service.needs.hydration = 70
	service.needs.fatigue = 80
	service.needs.harvests["test.harvest"] = 200.0
	player.position = rest.position
	rest.callback.call()
	check(not paused and not player.ui_blocked, "Rest selection paused or blocked live actions")
	check(work.start_selected(), "Short rest failed to start")
	work.tick(2.99)
	check(player.health_component.hp == 20 and service.needs.fatigue == 80, "Rest granted early recovery")
	work.tick(.01)
	check(player.health_component.hp == 60 and player.mana_component.mp == 40 and service.needs.fatigue == 55 and service.needs.nutrition == 65 and service.needs.hydration == 60, "Short rest costs/recovery inconsistent")
	game.progress.choices.waterworks_choice = "conduit"
	rest.callback.call()
	work.selected = 1
	check(work.start_selected(), "Full rest failed")
	work.tick(6)
	check(player.health_component.hp == 100 and player.mana_component.mp == 60 and service.needs.fatigue == 0 and service.needs.nutrition == 45 and service.needs.hydration == 35 and service.needs.harvests["test.harvest"] == 200 and player.mana_component.mp_regen_rate == 5, "Full rest reset provisions/harvests or failed recovery")
	service.needs.nutrition = 0
	service.needs.hydration = 0
	var inventory := service.supplies.serialize()
	rest.callback.call()
	work.selected = 2
	check(work.start_selected(), "Empty inventory prevented emergency food")
	work.tick(2)
	check(service.needs.nutrition == 60 and service.needs.hydration == 60 and service.supplies.serialize() == inventory and service.needs.meal_remaining == 0, "Emergency food generated goods or meal buffs")
	# Pause and offline time do not advance needs or regeneration effects.
	game.ui.show_pause()
	var snapshot := service.needs.serialize()
	service.tick(600)
	check(snapshot == service.needs.serialize(), "Paused menu drained needs")
	game.ui.close_modal()
	service.needs.nutrition = 10
	service.needs.hydration = 10
	service.needs.fatigue = 90
	service.apply_recovery()
	player.mana_component.mp = 0
	player.mana_component.mp_regen_rate = 4
	player.mana_component.mp_regen_delay = 0
	player.mana_component.tick(10)
	check(player.mana_component.mp == 7, "Dehydration/fatigue did not use existing MP regeneration")
	var sm := player.skill_manager
	sm.restrict_actions = false
	player.mana_component.mp = 60
	var action := sm.pool.get_skill("water_call")
	var tired := sm.combinations.preview(action, player)
	check("疲劳" in sm.combinations.describe_plan(tired), "Cast preview omitted fatigue explanation")
	service.needs.fatigue = 59.99
	var ordinary := sm.combinations.preview(action, player)
	check(is_equal_approx(tired.preparation, ordinary.preparation * 1.25), "Fatigue changed non-preparation costs or stacked incorrectly")
	sm.equip_slot(0, action)
	check(sm.use_source("slot_0", player, CastContext.simple(player, Vector2.RIGHT, action)), "Fatigue rollback spell could not start")
	var mp := player.mana_component.mp
	service.needs.fatigue = 60
	sm.combinations.tick(1)
	check(sm.combinations.pending.is_empty() and mp == player.mana_component.mp and service.supplies.serialize() == inventory, "Fatigue stage changed during preparation without atomic cancellation")
	service.needs.nutrition = 3
	service.needs.hydration = 4
	service.needs.fatigue = 99
	player.health_component.invincible = false
	CombatExecutor.report_hit(null, player, 999, player.position, null, ["test"])
	game.ui.close_modal()
	game._change_region("camp")
	check(not player.health_component.is_dead and player.health_component.hp == 50 and player.mana_component.mp == 30 and service.needs.nutrition == 35 and service.needs.hydration == 35 and service.needs.fatigue == 60 and service.supplies.serialize() == inventory, "Death recovery created supplies, refilled fully or trapped exhausted character")
	await fixture.close()
	if errors.is_empty(): print("Survival rest passed: explicit short/full rest, hunger/thirst costs, emergency fallback, no travel/load refill, paused clocks, existing regen, preview rollback and bounded death recovery")
	quit(0 if errors.is_empty() else 1)
