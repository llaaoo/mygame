extends SceneTree
## Controlled integration: positions/AI and one cloth are fixtures, not a natural playthrough.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const PRESS := "archive.index_press"
const SHORTCUT := "archive.index_return"
const QUEST := "river.first_expedition"
var game: GrayriverGame
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(count:=5) -> void:
	for i in count: await process_frame
func read(id: String) -> void:
	for entry in game.current_data.discoveries:
		if entry.id!=id: continue
		game.player.position=entry.pos
		check(game.progress_service.discover(entry),"Discovery refused: "+id)
		return
	check(false,"Missing authored discovery: "+id)
func site() -> SpellWorldObject:
	for child in game.region_root.get_children():
		if child is SpellWorldObject and child.spec.id==PRESS: return child
	return null
func quest() -> ExplorationQuestData:
	for entry in game.quests:
		if entry.id==QUEST: return entry
	return null
func write_save(bytes: PackedByteArray) -> void:
	for suffix in ["",".bak"]:
		var file:=FileAccess.open("user://save_3.sav"+suffix,FileAccess.WRITE)
		check(file!=null,"Could not restore the game-generated branch checkpoint")
		if file: file.store_buffer(bytes); file.close()
func run() -> void:
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	var task:=quest()
	check(task!=null,"First expedition quest absent")
	if not task: await fixture.close(); quit(1); return
	check(not task.available(game.progress),"First expedition was revealed before the handbook")
	read("river.handbook")
	check(task.stage(game.progress)==ExplorationQuestData.Stage.ACTIVE,"Handbook did not introduce the short expedition")
	read("river.fire")
	await fixture.travel("river_archive")
	var region:=game.current_data
	check(MapGeometry.errors(region).is_empty(),"Archive interactions or routes are not reachable on runtime navigation")
	check(region.encounters.size()==3 and region.discoveries.size()==6 and region.spell_objects.size()==1,"Archive content exceeded the declared encounter/note/mechanism scope")
	check(region.exits.size()==2 and region.exits[0].required_claims.is_empty() and not region.exits[0].requires_clear,"Original unconditional retreat was lost")
	var shortcut:=region.exits.filter(func(exit: ExplorationExitData):return exit.id==SHORTCUT)[0] as ExplorationExitData
	check(shortcut.arrival==Vector2(-2700,-1800) and region.exits[0].arrival==shortcut.arrival,"Archive returns did not resolve the same corrected safe landing")
	check(not shortcut.claims_satisfied(game.progress),"Return shortcut opened before its mechanism")
	game._use_exit(shortcut); await frames()
	check(game.region_id=="river_archive","Locked shortcut changed regions")
	var navigation:=game.session.region.navigation
	check(not navigation.path(region.authored_entry,Vector2(-100,-580)).is_empty() and not navigation.path(region.authored_entry,Vector2(-100,560)).is_empty(),"North bypass or south approach was sealed by the new shelves")
	read("river.pulse")
	for enemy in game.active_enemies.duplicate(): enemy.take_damage(10000)
	await frames()
	read("river.dossier")
	check(not task.is_complete(game.progress) and not task.can_claim(game.progress,game.player.stats_component),"Fire knowledge and dossier bypassed the new mechanism requirement")
	var press:=site()
	check(press!=null and press.spec.materials.is_empty(),"Press absent or introduced an undeclared material reward")
	if not press: await fixture.close(); quit(1); return
	check(press.spec.work_methods.size()==1 and press.spec.work_methods[0].material_costs=={"cloth":1},"Manual alternative changed its cloth budget")
	game.player.position=press.position-Vector2(40,0)
	game._save_progress()
	var branch_save:=FileAccess.get_file_as_bytes("user://save_3.sav")
	# Retain the game-generated pre-mechanism checkpoint for a separate controlled
	# GUI casting sample. Its position, knowledge and defeated guards are fixtures;
	# it must not be presented as the natural new-journey/combat evidence.
	var debug_save:=FileAccess.open("user://archive_before_press.sav",FileAccess.WRITE)
	check(debug_save!=null,"Could not retain the controlled pre-press checkpoint")
	if debug_save: debug_save.store_buffer(branch_save); debug_save.close()
	print("ARCHIVE_BRANCH_FIXTURE "+ProjectSettings.globalize_path("user://archive_before_press.sav"))
	var before:=game.session.inventory.snapshot()
	# This route is checked with hit events only. Actual player casting needs its
	# own controlled GUI verification from the retained checkpoint above.
	CombatExecutor.report_hit(game.player,press,0,press.position,null,["impact"])
	check(not press.completed,"Impact alone bypassed the water-first route")
	CombatExecutor.report_hit(game.player,press,0,press.position,null,["water"])
	check(not press.completed,"Water alone completed the two-step mechanism")
	CombatExecutor.report_hit(game.player,press,0,press.position,null,["impact"])
	check(press.completed and game.progress.claims.has(PRESS) and game.session.inventory.snapshot()==before,"Water/impact did not commit once without extra material reward")
	check(not press.finish("water_impact") and game.session.inventory.snapshot()==before,"Repeat mechanism completion changed inventory")
	check(task.is_complete(game.progress) and not game.progress_service.claim_quest(task),"Archive allowed reporting away from town")
	check(shortcut.claims_satisfied(game.progress) and region.exits[0].claims_satisfied(game.progress),"Mechanism did not open the shortcut or broke the original return")
	game.player.position=shortcut.pos; game._use_exit(shortcut); await frames(10)
	check(game.region_id=="camp" and game.player.position.distance_to(shortcut.arrival)<8,"Opened shortcut did not return to the named forest landing")
	check(not game.progress_service.claim_quest(task),"Forest landing counted as the town reporting area")
	game.player.position=Vector2(-3500,2100)
	var points:=game.player.stats_component.attribute_points
	check(game.progress_service.claim_quest(task) and game.player.stats_component.attribute_points==points+task.attribute_points,"Town did not award the declared point budget")
	check(not game.progress_service.claim_quest(task) and game.player.stats_component.attribute_points==points+task.attribute_points,"Repeated report duplicated attribute points")
	game._save_progress(); await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true); task=quest()
	check(game.progress.claims.has(PRESS) and task.stage(game.progress)==ExplorationQuestData.Stage.REPORTED,"Cold reentry lost mechanism/report facts")
	var restored_points:=game.player.stats_component.attribute_points
	check(not game.progress_service.claim_quest(task) and game.player.stats_component.attribute_points==restored_points,"Cold reentry awarded the report twice")
	await fixture.travel("river_archive")
	check(site().completed and game.active_enemies.is_empty(),"Cold return refilled defeated guards or reset the press")
	await fixture.close()
	# Rewind the same game-generated checkpoint to validate the paid work alternative.
	write_save(branch_save)
	fixture=Fixture.new(self); game=await fixture.boot(true); press=site()
	check(game.region_id=="river_archive" and press!=null and not press.completed,"Unsolved branch checkpoint did not restore")
	if not press: await fixture.close(); quit(1); return
	var store:=game.session.inventory
	if store.count("player","cloth")==0: check(store.receive("player","cloth",1)==1,"Controlled manual-cost fixture has no capacity")
	game.player.position=press.position-Vector2(40,0)
	var cloth:=store.count("player","cloth")
	game.field_sites.inspect(press)
	check(game.player.field_work.start_selected(),"Could not start manual press work")
	game.player.field_work.tick(.3); game.player.position+=Vector2(180,0); game.player.field_work.tick(.1)
	check(not game.player.field_work.is_busy() and not press.completed and store.count("player","cloth")==cloth,"Interrupted work consumed cloth or completed the mechanism")
	game.player.position=press.position-Vector2(40,0); game.field_sites.inspect(press)
	check(game.player.field_work.start_selected(),"Manual work could not restart")
	game.player.field_work.tick(3)
	check(press.completed and store.count("player","cloth")==cloth-1 and game.progress.claims.has(PRESS),"Manual work failed to consume exactly one cloth and commit the same fact")
	check(not press.finish(press.spec.work_methods[0].id) and store.count("player","cloth")==cloth-1,"Repeated paid route consumed cloth again")
	game.player.field_work.close_panel(); await fixture.close()
	if failures.is_empty(): print("PASS archive adventure: original budgets, two reachable approaches, water/impact or interrupted paid work, claim-gated shortcut, handbook-introduced town report once and cold persistence; controlled positions, frozen AI and one-cloth fixture")
	quit(0 if failures.is_empty() else 1)
