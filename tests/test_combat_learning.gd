extends SceneTree
## Controlled integration, not a natural fight: positions, disabled AI and two
## lethal test hits isolate the existing corpse -> trade -> paid course boundary.
## No equipment, currency or martial knowledge is granted to the player fixture.
const Fixture := preload("res://tests/support/grayriver_fixture.gd")
const TEACHER := "river.enemy.service.trainer"
var game: GrayriverGame
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(count := 4) -> void:
	for i in count: await physics_frame
func enemy(id: String) -> Enemy:
	for candidate in game.active_enemies:
		if str(candidate.get_meta("frontier_claim", "")) == id: return candidate
	return null
func read(id: String) -> void:
	for entry in game.current_data.discoveries:
		if entry.id != id: continue
		game.player.position = entry.pos
		check(game.progress_service.discover(entry), "Could not read the existing route hint: " + id)
		return
	check(false, "Missing route hint: " + id)
func take_gear(id: String, definition: String, uid: String) -> void:
	check(game.loot.take(id, "equipment", definition, uid) == 1, "Could not take the actual corpse UID: " + definition)
	check(game.session.inventory.locate(uid) == "player.pack", "Corpse transfer replaced or lost the real UID")
func run() -> void:
	var fixture := Fixture.new(self); game = await fixture.boot(true)
	game.session.set_process(false)
	var store := game.session.inventory
	var martial := game.player.actor_context.martial
	var before_equipment := {}
	for id in store.definitions:
		if store.definitions[id] is EquipmentData or id == "coin": before_equipment[id] = store.count("player", id)
	var before_knowledge := martial.snapshot()
	read("river.handbook"); read("river.fire")
	check(martial.snapshot() == before_knowledge, "Reading either route granted martial knowledge")
	for id in before_equipment:
		check(store.count("player", id) == before_equipment[id], "Reading route hints granted equipment or money: " + str(id))
	# The handbook retains its existing inherited material reward; this check
	# isolates equipment/money/knowledge rather than deleting that original budget.
	var slots := game.player.skill_manager.shortcuts.snapshot()
	var offer := TrainingCatalog.default_catalog().offer("blade_breaker")
	check(offer != null and offer.costs == {"coin": 8} and offer.requirements.is_empty(), "Optional first blade course changed its existing price or added a route gate")
	if not offer: await fixture.close(); quit(1); return
	var technique := offer.technique
	check(technique.weapon_type == "blade" and technique.art_route("power").hit_rule == MartialRoute.HitRule.NONE and technique.art_route("flow").hit_rule == MartialRoute.HitRule.LAST, "Teaching no longer matches the actual light/heavy and final-hit route conditions")
	# Recover, wear and retain one real guard's weapon/armour. The second guard's
	# spare blade funds the lesson; neither the player's sole weapon nor money is injected.
	var guard := enemy("river.enemy.camp.forest.3")
	var spare_guard := enemy("river.enemy.camp.bridge_keeper")
	check(guard != null and spare_guard != null, "Existing real equipment sources are absent")
	if not guard or not spare_guard: await fixture.close(); quit(1); return
	var main_slot := str(EquipmentData.SlotType.RIGHT_HAND)
	var body_slot := str(EquipmentData.SlotType.CHEST)
	var kept_weapon := str(store.equipped(guard.actor_context.id).get(main_slot, ""))
	var kept_armour := str(store.equipped(guard.actor_context.id).get(body_slot, ""))
	var spare_weapon := str(store.equipped(spare_guard.actor_context.id).get(main_slot, ""))
	guard.take_damage(10000); spare_guard.take_damage(10000); await frames()
	game.player.position = (game.loot.corpses["river.enemy.camp.forest.3"] as GrayriverLootCorpse).position
	take_gear("river.enemy.camp.forest.3", "river_sabre", kept_weapon)
	take_gear("river.enemy.camp.forest.3", "river_coat", kept_armour)
	check(store.equip("player", kept_weapon).accepted and store.equip("player", kept_armour).accepted, "Recovered retained equipment could not be worn")
	game.player.position = (game.loot.corpses["river.enemy.camp.bridge_keeper"] as GrayriverLootCorpse).position
	take_gear("river.enemy.camp.bridge_keeper", "river_sabre", spare_weapon)
	game.player.position = TownServices.POINT + Vector2(0, 35); await frames()
	var proceeds := game.town_services.price(spare_weapon, false)
	var player_money := store.count("player", "coin")
	var merchant_money := store.count(TownServices.MERCHANT, "coin")
	check(proceeds >= int(offer.costs.coin) and game.town_services.transact(spare_weapon, true).accepted, "Unmodified spare blade could not fund the existing first lesson")
	check(store.locate(spare_weapon) == TownServices.MERCHANT + ".pack" and store.count("player", "coin") == player_money + proceeds and store.count(TownServices.MERCHANT, "coin") == merchant_money - proceeds, "Sale did not conserve actual equipment and both money bags")
	check(store.equipped("player").get(main_slot) == kept_weapon and store.equipped("player").get(body_slot) == kept_armour, "Funding a lesson consumed the retained combat equipment")
	var teacher := game.session.actor_for_id(TEACHER) as ServiceNPC
	check(teacher != null, "Real trainer absent")
	if not teacher: await fixture.close(); quit(1); return
	game.player.position = teacher.position + Vector2(0, 40); await frames()
	var conversation := game.session.conversations.begin(TEACHER)
	check(bool(conversation.accepted), "Current position/schedule could not reach the real trainer")
	if not conversation.accepted: await fixture.close(); quit(1); return
	var service := game.session.conversations.choose(int(conversation.token), "training")
	check(bool(service.accepted) and service.get("service") == "training", "Existing NPC topic did not lead to the original course service")
	player_money = store.count("player", "coin")
	var teacher_money := store.count(TEACHER, "coin")
	check(TechniqueLearning.purchase(offer, game.player.actor_context, TEACHER).accepted, "Earned real money could not purchase martial knowledge")
	check(store.count("player", "coin") == player_money - 8 and store.count(TEACHER, "coin") == teacher_money + 8 and martial.learned.has("blade_breaker"), "Paid lesson did not transfer exactly its existing cost and knowledge")
	check(martial.route_equipped("blade_breaker", "power") and martial.route_equipped("blade_breaker", "flow") and game.player.skill_manager.shortcuts.snapshot() == slots, "Learning failed to configure routes or replaced an independent spell/item shortcut")
	var paid_items := store.snapshot(); var paid_knowledge := martial.snapshot()
	check(not TechniqueLearning.purchase(offer, game.player.actor_context, TEACHER).accepted and store.snapshot() == paid_items and martial.snapshot() == paid_knowledge, "Duplicate lesson charged, changed the loadout or generated an item")
	game._save_progress(); await fixture.close()
	fixture = Fixture.new(self); game = await fixture.boot(true); game.session.set_process(false)
	store = game.session.inventory; martial = game.player.actor_context.martial
	check(martial.snapshot() == paid_knowledge and game.player.skill_manager.shortcuts.snapshot() == slots, "Cold reentry lost learned routes or changed shortcuts")
	check(store.locate(spare_weapon) == TownServices.MERCHANT + ".pack" and store.equipped("player").get(main_slot) == kept_weapon and store.equipped("player").get(body_slot) == kept_armour, "Cold reentry duplicated sold gear or lost retained equipment identity")
	check(store.count("player", "coin") == player_money - 8 and store.count(TEACHER, "coin") == teacher_money + 8, "Cold reentry refunded or charged the lesson again")
	check(not TechniqueLearning.purchase(offer, game.player.actor_context, TEACHER).accepted, "Cold reentry made a paid course repeatable")
	await fixture.close()
	if failures.is_empty(): print("PASS combat learning: controlled existing corpse UID recovery, retained blade/armour, spare sale, real NPC service, paid optional course, route/quickslot separation and cold persistence; not normal-AI or input evidence")
	quit(0 if failures.is_empty() else 1)
