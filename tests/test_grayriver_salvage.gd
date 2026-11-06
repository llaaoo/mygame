extends SceneTree
const Fixture := preload("res://tests/support/grayriver_fixture.gd")
var errors: Array[String] = []
var game: GrayriverGame
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message); push_error(message)
func read(id: String) -> void:
	for note in game.current_data.discoveries:
		if note.id == id:
			game.player.position = note.pos
			check(game.progress_service.discover(note),"Could not investigate "+id)
			return
	check(false,"Missing authored discovery "+id)
func quest(id: String) -> ExplorationQuestData:
	for entry in game.quests:
		if entry.id == id: return entry
	return null
func run() -> void:
	check(GrayriverValidator.validate(GrayriverDefinition.data()).is_empty(),"Salvage content data invalid")
	var chapter := GrayriverDefinition.build()
	var validation := ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(chapter))
	for error in validation: check(false,error)
	var invalid := chapter.duplicate(true)
	var unknown := EquipmentData.new()
	unknown.id = "unknown_worn_gear"
	unknown.slot_type = EquipmentData.SlotType.RIGHT_HAND
	invalid.regions[0].encounters[0].character.equipment[0] = unknown
	check(not ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(invalid)).is_empty(),"Unrecoverable worn gear passed validation")
	var fixture := Fixture.new(self)
	game = await fixture.boot(true)
	var supplies := game.survival.supplies
	var site: DeliverySiteData
	for entry in game.current_data.delivery_sites:
		if entry.id == "river.salvage_delivery": site = entry
	var node: ExplorationInteractable
	for child in game.region_root.get_children():
		if child is ExplorationInteractable and child.title == site.title: node = child
	game.player.position = node.position
	check(not game.deliveries._reason(site.methods[0],node,site).is_empty(),"Material delivery ignored its discovered evidence")
	read("river.caravan_manifest")
	read("river.salvage_cache")
	var before := supplies.serialize()
	for note in game.current_data.discoveries:
		if note.id == "river.salvage_cache": check(not game.progress_service.discover(note) and supplies.serialize() == before,"Cargo cache refilled")
	# The non-combat source is enough; no enemy is defeated to obtain this cargo.
	await fixture.travel("river_mine")
	read("river.miners_stash")
	read("river.quartermaster_note")
	check(not quest("river_quartermaster").is_complete(game.progress),"Quartermaster report completed without recovered evidence")
	await fixture.travel("camp")
	for child in game.region_root.get_children():
		if child is ExplorationInteractable and child.title == site.title: node = child
	game.player.position = node.position
	game.deliveries.inspect(node,site)
	before = supplies.serialize()
	check(game.player.field_work.start_selected(),"Actual salvage handover did not start")
	game.player.take_damage(1)
	check(not game.player.field_work.is_busy() and supplies.serialize() == before and not game.progress.claims.has(site.id),"Interrupted delivery spent cargo or completed")
	check(game.player.field_work.start_selected(),"Salvage retry failed")
	game.player.field_work.tick(2)
	check(game.progress.claims.has(site.id) and supplies.count("charcoal") == int(before.amounts.charcoal)-2 and supplies.count("crystal") == int(before.amounts.crystal)-1 and supplies.count("sap") == int(before.amounts.sap)-1,"Delivery did not consume actual cargo")
	check(supplies.count("grain") == 2 and supplies.count("herb") == 2,"Salvage gave another site's reward")
	before = supplies.serialize()
	check(not game.deliveries._complete(site.methods[0],node,site) and supplies.serialize() == before,"Repeated cargo handover charged or rewarded")
	check(game.progress_service.claim_quest(quest("river_salvage")) and not game.progress_service.claim_quest(quest("river_salvage")),"Cargo quest completion/reward is not one-shot")
	# An old cleared mine still offers the newly added optional character, without
	# resurrecting its original enemies or resetting old objectives and rewards.
	game.progress.cleared["river_mine"] = true
	await fixture.travel("river_mine")
	check(game.active_enemies.size() == 1 and game.active_enemies[0].character_definition.id == "river_mine_quartermaster","Legacy cleared mine lost new optional content or resurrected old guards")
	var enemy := game.active_enemies[0]
	game.player.position = enemy.position
	enemy.take_damage(1000)
	for i in range(4): await process_frame
	check(game.loot.take("river.enemy.river_mine.quartermaster","equipment","river_survey_spear") == 1,"Named character did not drop its visible copper spear")
	check(quest("river_quartermaster").is_complete(game.progress),"Recovered evidence did not update the optional report")
	await fixture.travel("camp")
	game.player.position = Vector2(-3500,2100)
	check(game.progress_service.claim_quest(quest("river_quartermaster")),"Named character report not accepted in town")
	game._save_progress()
	var saved := game.progress.serialize_save_data()
	check(game.progress.validate_save_data(saved),"Content/loot progress cannot persist")
	await fixture.close()
	if errors.is_empty(): print("Grayriver salvage passed: non-combat cargo route, real interruptible delivery, one-shot caches/rewards, optional named encounter in old cleared region and recoverable equipment evidence")
	quit(0 if errors.is_empty() else 1)
