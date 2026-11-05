extends SceneTree
const Fixture := preload("res://tests/support/mvp_fixture.gd")
var game: MVPGame
var errors: Array[String] = []
class RejectingExecutor extends SkillExecutor:
	func execute(_skill: SkillData, _context: CastContext) -> bool: return false
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
		push_error(message)
func frames(count := 6) -> void:
	for i in range(count): await process_frame
func travel(id: String) -> void:
	game.ui.close_modal()
	game._change_region(id)
	for enemy in game.active_enemies:
		enemy.set_physics_process(false)
		enemy.get_node("StateChart").process_mode = Node.PROCESS_MODE_DISABLED
	await frames()
func find_interaction(title: String) -> ExplorationInteractable:
	for child in game.region_root.get_children():
		if child is ExplorationInteractable and child.title == title: return child
	return null
func modal_text() -> String:
	var text := ""
	for label in game.ui.modal.find_children("*", "RichTextLabel", true, false): text += label.text
	return text
func run() -> void:
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	GameRuntime.instance.set_process(false)
	var player := game.player
	var sm := player.skill_manager
	sm.restrict_actions = false
	check(player.combat_component.attack_damage == 18 and player.health_component.max_hp == 100 and player.mana_component.max_mp == 60, "Exploration tuning changed caps or failed to change melee")
	var equipment := player.get_node("EquipmentManager") as EquipmentManager
	check("每份再加3 MP" in game.equipment_service.build_summary(game.catalog.equipment.cadence_gloves) and "%d" not in game.equipment_service.build_summary(game.catalog.equipment.cadence_gloves), "Gloves comparison left a format placeholder")
	# First reading is concise, while the stored record and explicit details stay complete.
	var handbook: ExplorationDiscoveryData
	for note in game.current_data.discoveries:
		if note.id == "material_handbook": handbook = note
	game.presenter.inspect_discovery(handbook, find_interaction(handbook.title))
	check(handbook.intro_text in modal_text() and handbook.text not in modal_text(), "First reading still dumps advanced instructions")
	var inventory := sm.combinations.supplies.serialize()
	game.presenter.inspect_discovery(handbook, null, true)
	check(handbook.text in modal_text() and inventory == sm.combinations.supplies.serialize(), "Full notes were lost or rereading repeated rewards")
	game.ui.close_modal()
	# Actual cast intent, rather than a hard-coded spell, drives the HUD.
	sm.equip_slot(3, sm.pool.get_skill("water_call"))
	sm.combinations.supplies.configure("water_call", "frost_salt")
	var context := CastContext.at_position(player, player.global_position, sm.get_slot(3).data)
	var press := Action.cast("slot_3", Vector2.RIGHT, player)
	press.cast_context = context
	player.input_controller.resolve_action(press)
	var hud := game.get_node("HUDLayer")
	hud.skill_bar._process(.2)
	check(hud.skill_bar._combination_hint.text.begins_with("水引 →") and "霜盐" in hud.skill_bar._combination_hint.text and "落点半径" in hud.skill_bar._combination_hint.text, "Water aim still previews fire, wrong materials or wrong scope")
	player.casting.aiming_sources.right = true
	check(player.casting.aimed_source() == "right", "Latest pressed source did not win")
	player.casting.aiming_sources.erase("right")
	check(player.casting.aimed_source() == "slot_3", "Releasing a second source lost the held water action")
	player.casting.cancel_all()
	sm.unequip_hand("right")
	hud.skill_bar._process(.2)
	check(hud.skill_bar._combination_hint.text.begins_with("水引 →") and not hud.skill_bar._cost_labels[5].text.is_empty(), "Empty right hand disabled hotbar previews")
	sm.equip_hand("right", sm.pool.get_skill("ignite"))
	# Exhaustion feedback is emitted only after a successful, irreversible commit.
	player.global_position = Vector2.ZERO
	await physics_frame
	sm.equip_slot(4, sm.pool.get_skill("fire_sigil"))
	sm.combinations.learned_rules.fire_sigil_fireball = true
	check(sm.use_slot(4, player, Vector2.RIGHT), "Fire field preparation rejected")
	sm.combinations.tick(1)
	var field := sm.combinations.field
	field.charges = 1
	var notices: Array[String] = []
	sm.combinations.feedback_requested.connect(func(text: String): notices.append(text))
	var original := sm.executor
	var reject := RejectingExecutor.new()
	sm.add_child(reject)
	sm.executor = reject
	var mana := player.mana_component.mp
	check(sm.use_hand("right", player, Vector2.RIGHT), "Rejection probe preparation failed")
	sm.combinations.tick(1)
	check(field.charges == 1 and player.mana_component.mp == mana and notices.is_empty(), "Rejected cast leaked charge/mana/exhaustion feedback")
	sm.executor = original
	reject.queue_free()
	check(sm.use_hand("right", player, Vector2.RIGHT), "Last-charge cast preparation failed")
	sm.combinations.tick(1)
	check(notices.size() == 1 and "充能耗尽" in notices[0] and "近身半径" in notices[0] and game.ui.message.text == notices[0], "Exhaustion did not explain the real fallback")
	# Old claims alone unlock reverse entrances, without granting or consuming anything.
	var regions := ["archive", "drain", "cistern"]
	var claims := ["magic.charged_crystal", "magic.thermal_cache", "magic.waterworks_conductor"]
	for i in range(regions.size()):
		var exit: ExplorationExitData
		for candidate in game.catalog.regions[regions[i]].exits:
			if not candidate.camp_return_title.is_empty(): exit = candidate
		await travel("camp")
		check(find_interaction(exit.camp_return_title) == null, "Reverse passage appeared before its claim")
		game.progress.claims[claims[i]] = true
		await travel("camp")
		inventory = sm.combinations.supplies.serialize()
		var passage := find_interaction(exit.camp_return_title)
		check(passage != null, "Existing claim failed to unlock reverse passage")
		passage.callback.call()
		await frames(10)
		check(game.region_id == regions[i] and player.position.distance_to(exit.pos) < 1 and inventory == sm.combinations.supplies.serialize(), "Reverse passage lost arrival position or changed supplies")
	# Local trials preserve world completion and never create kill rewards.
	game.progress.cleared.archive = true
	game.progress.completed = true
	await travel("archive")
	var before := game.progress.serialize_save_data()
	var experience := player.stats_component.experience
	var level := player.stats_component.level
	check(game.can_practice() and game.progress_service.practice_encounters() and not game.progress_service.practice_encounters(), "Local practice ignored availability or duplicated enemies")
	check(game.active_enemies.size() == 3, "Practice lost the authored encounter")
	for enemy in game.active_enemies.duplicate():
		check(not enemy.rewards_enabled and enemy.health_drop_amount == 8 and enemy.mana_drop_amount == 12, "Practice/tuned drop policy was not applied")
		CombatExecutor.report_hit(player, enemy, 999, enemy.position, null, ["melee"])
	await frames()
	check(game.active_enemies.is_empty() and not game.practice_active and game.progress.completed and before.cleared == game.progress.cleared and before.claims == game.progress.claims, "Practice completion rewrote exploration state")
	check(player.stats_component.experience == experience and player.stats_component.level == level, "Practice awarded kill experience")
	for child in game.region_root.get_children(): check(not child is SoulRemnant and not child is Pickup, "Practice generated souls or pickups")
	check(game.progress_service.practice_encounters(), "Completed local practice could not be repeated")
	var before_death := sm.combinations.supplies.serialize()
	player.health_component.invincible = false
	CombatExecutor.report_hit(null, player, 999, player.global_position, null, ["environment"])
	check(game.ui.modal_locked and game.progress.completed and game.progress.cleared.archive, "Practice death erased exploration completion")
	await travel("camp")
	check(not game.practice_active and not game.can_practice() and game.progress.cleared.archive and player.health_component.hp == 100 and before_death == sm.combinations.supplies.serialize(), "Leaving practice lost progress, refunded supplies or kept practice active")
	game.presenter.show_arrival()
	check("监狱封锁已解除" in modal_text() and "先读营地材料手册" not in modal_text(), "Completed save still displays the new-player introduction")
	game.ui.close_modal()
	check(SaveManager.instance.save_game(MVPGame.SAVE_SLOT), "Practice/shortcut progress save failed")
	inventory = sm.combinations.supplies.serialize()
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	check(game.progress.completed and game.progress.cleared.archive and not game.practice_active and inventory == game.player.skill_manager.combinations.supplies.serialize(), "Disk restore persisted practice enemies or lost supplies/progress")
	check(find_interaction("检修通路：军械档案室") != null, "Disk restore lost reverse passage")
	await fixture.close()
	if errors.is_empty(): print("Playtest iteration passed: intent previews, exhaustion rollback, concise/full notes, glove costs, bidirectional old-claim shortcuts and reward-free regional practice")
	quit(0 if errors.is_empty() else 1)
