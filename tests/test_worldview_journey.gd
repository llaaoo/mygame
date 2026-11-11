extends "res://tests/support/input_scene_probe.gd"
## Controlled integration: fixed positions and frozen AI isolate the rite transaction.
## Normal-AI travel/combat belongs to the separately recorded native playthrough.
const Fixture := preload("res://tests/support/grayriver_fixture.gd")
const SITE := "awakening.archive"

func read_record(id: String) -> void:
	for entry in game.current_data.discoveries:
		if entry.id != id: continue
		game.ui.close_modal()
		game.player.position = entry.pos
		check(game.progress_service.discover(entry), "Could not read authored record: " + id)
		return
	check(false, "Missing authored record: " + id)

func rite_node() -> ExplorationInteractable:
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.has_meta("awakening_site"):
			if node.get_meta("awakening_site").id == SITE: return node
	return null

func open_rite() -> ExplorationInteractable:
	game.ui.close_modal()
	game.player.field_work.close_panel()
	var node := rite_node()
	check(node != null, "Authored awakening site was not mounted")
	if not node: return null
	game.player.position = node.position + Vector2(0, 32)
	await frames(2)
	game.awakening.inspect(node, node.get_meta("awakening_site"))
	return node

func start_work() -> void:
	await key(KEY_F, true)
	await key(KEY_F, false)
	check(game.player.field_work.is_busy(), "Real F input did not start the selected rite stage")

func run() -> void:
	root.size = Vector2i(1152, 648)
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	var actor := game.player
	var magic := actor.actor_context.magic
	check(not magic.awakened and magic.aptitude, "New traveler must have latent aptitude without casting permission")
	check(actor.mana_component.mp == 0 and actor.mana_component.max_mp == 0, "New journey starts with usable mana")
	read_record("river.handbook")
	check(not actor.mana_component.can_cast() and actor.mana_component.mp == 0, "Reading the handbook granted awakening")
	read_record("river.fire")
	check(not actor.mana_component.can_cast(), "Reading an elemental formula bypassed awakening")
	read_record("river.pack")
	read_record("river.material.cloth_bundle.v1")
	var store := game.session.inventory
	var sword := store.find_owned("player", "river_sabre")
	check(not sword.is_empty() and store.equip("player", sword).accepted, "Ordinary start did not provide a real usable weapon")
	var weapon_count := store.count("player", "river_sabre", true)
	for entry in game.current_data.discoveries:
		if entry.id == "river.pack": game.progress_service.discover(entry)
	check(store.count("player", "river_sabre", true) == weapon_count, "Repeated ration collection duplicated its weapon")
	var known := game.progress.actions.duplicate()
	game._save_progress()
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	actor = game.player
	check(not actor.actor_context.magic.awakened and actor.mana_component.max_mp == 0, "New-format ordinary save was migrated into a caster")
	check(game.progress.actions == known and game.session.inventory.item(sword) != null, "Ordinary cold reentry lost knowledge or weapon UID")

	await fixture.travel("river_archive")
	var node := await open_rite()
	if not node:
		await fixture.close(); quit(1); return
	var spec := node.get_meta("awakening_site") as AwakeningSiteData
	check(not game.player.field_work.start_selected(), "Rite ignored missing exploration prerequisites")
	game.player.field_work.close_panel()
	# This is a controlled transaction fixture, not normal combat evidence.
	for enemy in game.active_enemies: enemy.position = Vector2(10000, 10000)
	read_record("river.dossier")
	var press: SpellWorldObject
	for candidate in game.region_root.get_children():
		if candidate is SpellWorldObject and candidate.spec.id == "archive.index_press": press = candidate
	check(press != null, "Nonmagical preparation mechanism is missing")
	if not press:
		await fixture.close(); quit(1); return
	store = game.session.inventory
	var cloth := store.count("player", "cloth")
	check(cloth > 0, "The authored start lacks the cloth needed for manual preparation")
	actor.position = press.position - Vector2(40, 0)
	game.field_sites.inspect(press)
	await start_work()
	actor.field_work.tick(3.0)
	check(press.completed and store.count("player", "cloth") == cloth - 1, "Manual preparation failed to spend exactly one real cloth")
	check(not actor.actor_context.magic.awakened and actor.mana_component.mp == 0, "Manual repair secretly awakened the traveler")
	var task: ExplorationQuestData
	for quest in game.quests:
		if quest.id == "river.first_expedition": task = quest
	check(task != null and task.is_complete(game.progress), "First expedition requires awakening or a spell")

	node = await open_rite()
	var work := actor.field_work
	var original_hp := actor.health_component.max_hp
	var original_stamina := actor.actor_context.actions.stamina.maximum
	var original_items := store.snapshot_owners(["player"])
	await start_work()
	check(is_equal_approx(float(work.pending.get("duration", 0)), 6.0), "Crafting efficiency shortened the aptitude trial")
	work.tick(1.0)
	actor.position += Vector2(140, 0)
	work.tick(.1)
	check(not work.is_busy() and not game.progress.claims.has(spec.trial_claim), "Moving did not interrupt the trial")
	check(store.snapshot_owners(["player"]) == original_items and not actor.actor_context.magic.awakened, "Interrupted trial charged resources or granted magic")

	node = await open_rite()
	await start_work()
	var nearby_guard := game.active_enemies[0]
	nearby_guard.position = actor.position + Vector2(160, 0)
	work.tick(.1)
	check(not work.is_busy() and not game.progress.claims.has(spec.trial_claim), "An approaching hostile did not stop the trial")
	nearby_guard.position = Vector2(10000, 10000)

	node = await open_rite()
	await start_work()
	work.tick(6.0)
	check(game.progress.claims.has(spec.trial_claim) and not actor.actor_context.magic.awakened, "Aptitude trial did not remain separate from consent")
	check(not work.is_busy() and not work.panel.visible, "Trial automatically began the irreversible acceptance")
	node = await open_rite()
	check(work.panel.visible and not paused, "Acceptance inspection must leave the world running")
	await key(KEY_ESCAPE, true); await key(KEY_ESCAPE, false)
	check(not work.panel.visible and not actor.actor_context.magic.awakened and actor.health_component.max_hp == original_hp, "Deferring awakening charged its price")

	game._save_progress()
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	actor = game.player; store = game.session.inventory
	check(not actor.actor_context.magic.awakened and game.progress.claims.has(spec.trial_claim), "Cold reentry lost the completed trial or forced acceptance")
	node = await open_rite()
	work = actor.field_work
	await start_work()
	check(is_equal_approx(float(work.pending.get("duration", 0)), 4.0), "Acceptance duration changed with crafting progression")
	work.tick(.5)
	actor.health_component.invincible = false
	CombatExecutor.report_hit(null, actor, 1, actor.position, null, ["test"])
	check(not work.is_busy() and not actor.actor_context.magic.awakened, "Damage did not interrupt acceptance before charging the cost")
	check(actor.health_component.max_hp == original_hp and is_equal_approx(actor.actor_context.actions.stamina.maximum, original_stamina), "Interrupted acceptance permanently reduced attributes")
	node = await open_rite()
	await start_work()
	work.tick(4.0)
	magic = actor.actor_context.magic
	check(magic.awakened and not magic.legacy_exempt and actor.mana_component.can_cast(), "Accepted rite did not grant real casting permission")
	check(actor.health_component.max_hp == original_hp - 10 and is_equal_approx(actor.actor_context.actions.stamina.maximum, original_stamina - 10.0), "Permanent price did not match the declared HP/stamina loss")
	check(actor.mana_component.max_mp == 60 and actor.mana_component.mp == 0, "Awakening changed its declared capacity or silently refilled MP")
	check(game.progress.claims.has(SITE) and store.item(sword) != null, "Awakening lost its receipt or real equipment")
	var paid_state := magic.serialize_save_data()
	var paid_hp := actor.health_component.max_hp
	var paid_stamina := actor.actor_context.actions.stamina.maximum
	node = await open_rite()
	await key(KEY_F, true); await key(KEY_F, false)
	actor.field_work.tick(4.0)
	check(not actor.field_work.is_busy() and actor.actor_context.magic.serialize_save_data() == paid_state, "Repeated inspection charged the rite twice")
	game.ui.close_modal(); actor.field_work.close_panel()
	game._save_progress()
	await fixture.close()
	fixture = Fixture.new(self)
	game = await fixture.boot(true)
	actor = game.player
	check(actor.actor_context.magic.serialize_save_data() == paid_state and actor.mana_component.can_cast(), "Cold reentry lost awakening identity or charged again")
	check(actor.health_component.max_hp == paid_hp and is_equal_approx(actor.actor_context.actions.stamina.maximum, paid_stamina), "Cold reentry changed permanent awakening price")
	check(game.progress.claims.has("archive.index_press") and game.progress.claims.has(SITE) and game.session.inventory.item(sword) != null, "Rite reload lost earlier exploration or real equipment")
	await fixture.close()
	if failures.is_empty(): print("PASS worldview journey: ordinary new/cold start, knowledge vs qualification, one-time physical starter weapon, nonmagical preparation/first expedition, real F/Esc rite input, movement/damage interruption, explicit consent, exact permanent price once and cold persistence; controlled positions and frozen AI")
	quit(0 if failures.is_empty() else 1)
