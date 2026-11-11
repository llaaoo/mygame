extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var game: MVPGame
var errors: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		errors.append(text)
		push_error(text)
func frames(count := 5) -> void:
	for i in range(count): await process_frame
func open_site() -> SpellWorldObject:
	game.player.field_work.cancel()
	game.player.field_work.close_panel()
	game.ui.close_modal()
	game._change_region("camp")
	game.player.global_position = Vector2.ZERO
	await frames()
	for node in game.region_root.get_children():
		if node is SpellWorldObject and node.spec.id == "test.worksite": return node
	return null
func finish_site(_spec: SpellPuzzleData) -> void:
	game.player.field_work.cancel("设备已解封")
	game.player.field_work.close_panel()
func run() -> void:
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	GameRuntime.instance.set_process(false)
	var spec := SpellPuzzleData.new()
	spec.id = "test.worksite"
	spec.title = "测试设备"
	spec.pos = Vector2(48, 0)
	spec.required_claims = ["test.blueprint"]
	spec.pickup_claim = "test.part"
	spec.pickup_title = "测试部件"
	var route := SpellPuzzleRoute.new()
	route.id = "fire"
	route.steps = ["fire"]
	spec.routes = [route]
	var force := FieldWorkMethod.new()
	force.id = "force"
	force.title = "撬拆"
	force.required_attributes = {"strength": 14}
	force.duration = 2
	var patch := FieldWorkMethod.new()
	patch.id = "patch"
	patch.title = "修补"
	patch.material_costs = {"resin": 1, "crystal": 2}
	patch.duration = 1.5
	spec.work_methods = [force, patch]
	game.catalog.regions.camp.spell_objects.append(spec)
	var site := await open_site()
	var player := game.player
	var work := player.field_work
	var supplies := player.skill_manager.combinations.supplies
	supplies.grant({"resin": 4, "crystal": 8})
	game.field_sites.inspect(site)
	check(work.panel.visible and not paused and not player.ui_blocked, "Inspecting work paused/blocked combat")
	check(not work.start_selected(), "Missing blueprint or attributes were ignored")
	game.progress.claims["test.blueprint"] = true
	check(not work.start_selected(), "Insufficient strength accepted")
	var key := InputEventKey.new()
	key.keycode = KEY_C
	key.physical_keycode = KEY_C
	key.pressed = true
	work._input(key)
	check(work.selected == 1 and not paused, "Q did not switch live work methods")
	player.health_component.hp = 60
	player.health_component.health_changed.emit(60, player.health_component.max_hp)
	var before := supplies.serialize()
	check(work.start_selected() and player.state_machine.current_state.name == "work", "Work failed to enter state")
	check(not work.start_selected(), "Duplicate work request restarted timer")
	work.tick(.7)
	check(supplies.serialize() == before and not site.completed, "Work charged before completion")
	# A heal cannot mask later damage within the same frame.
	player.health_component.heal(20)
	check(work.is_busy(), "Healing interrupted ongoing work")
	player.health_component.invincible = false
	CombatExecutor.report_hit(null, player, 5, player.position, null, ["test"])
	check(not work.is_busy() and supplies.serialize() == before and not site.completed, "Heal then damage did not cancel without payment")
	check(work.start_selected(), "Interrupted work could not restart")
	work.tick(1.5)
	check(site.completed and supplies.count("resin") == 3 and supplies.count("crystal") == 6 and game.progress.choices[spec.id] == "patch", "Successful work did not commit once")
	check(not game.progress.claims.has(spec.pickup_claim), "Opening teleported the part into inventory")
	check(game.field_sites.take_part(site) and not game.field_sites.take_part(site), "Part pickup was missing or duplicated")
	# Each interrupt leaves inventory and world state untouched.
	for interruption in ["move", "dodge", "attack", "cast", "E", "Esc", "menu", "attributes", "method", "equipment", "stock", "reject", "condition", "range", "region", "death"]:
		game.progress.claims.erase(spec.id)
		site = await open_site()
		game.field_sites.inspect(site)
		work.selected = 1
		before = supplies.serialize()
		check(work.start_selected(), "Interrupt probe did not start: " + interruption)
		match interruption:
			"move":
				player.input_controller.resolve_action(Action.move(Vector2.RIGHT, player))
			"dodge": player.resolve_action(Action.dodge(Vector2.UP, player))
			"attack": player.resolve_action(Action.melee(player))
			"cast":
				var cast := Action.cast("right", Vector2.RIGHT, player)
				cast.cast_context = CastContext.simple(player, Vector2.RIGHT, player.skill_manager.pool.get_skill("ignite"))
				player.resolve_action(cast)
			"E": player.resolve_action(Action.interact(player))
			"Esc":
				key.keycode = KEY_ESCAPE
				work._input(key)
				check(not paused, "Escape from work opened pause menu")
			"menu": game.ui.show_pause()
			"attributes":
				player.stats_component.modify_stat("agility", 1)
				work.tick(.1)
			"method":
				patch.duration = 2
				work.tick(.1)
				patch.duration = 1.5
			"equipment":
				(player.get_node("EquipmentManager") as EquipmentManager).loadout_revision += 1
				work.tick(.1)
			"stock":
				supplies.pay({"resin": supplies.count("resin")})
				before = supplies.serialize()
				work.tick(.1)
			"reject":
				work._commit_provider = func(_method: FieldWorkMethod) -> bool: return false
				work.tick(1.5)
			"condition":
				game.progress.claims.erase("test.blueprint")
				work.tick(.1)
				game.progress.claims["test.blueprint"] = true
			"range":
				player.position = Vector2(200, 200)
				work.tick(.1)
			"region": game._change_region("yard")
			"death":
				player.health_component.invincible = false
				CombatExecutor.report_hit(null, player, 999, player.position, null, ["test"])
		check(not work.is_busy() and supplies.serialize() == before and not game.progress.claims.has(spec.id), "Interrupt leaked resources/progress: " + interruption)
		if interruption == "stock": supplies.grant({"resin": 3})
	# A spell can win while an operation is pending, without charging its materials.
	site = await open_site()
	game.field_sites.inspect(site)
	work.selected = 1
	before = supplies.serialize()
	check(work.start_selected(), "Racing operation did not start")
	CombatExecutor.report_hit(player, site, 0, site.position, null, ["fire"])
	check(site.completed and not work.is_busy() and before == supplies.serialize(), "Spell completion raced and charged the work method")
	check(SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Work progress could not save")
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	check(game.progress.claims.has(spec.id) and game.progress.claims.has(spec.pickup_claim) and not game.player.field_work.is_busy(), "Disk restore lost completion or resumed transient work")
	await fixture.close()
	if errors.is_empty(): print("Field work passed: live keys, state, atomic finish, actual damage interruption, all cancellation paths, competing spell solution, pickup and disk recovery")
	quit(0 if errors.is_empty() else 1)
