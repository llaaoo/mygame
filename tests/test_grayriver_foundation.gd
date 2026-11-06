extends SceneTree
var errors: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func run() -> void:
	var chapter := GrayriverDefinition.build()
	var failures := ExplorationContentValidator.new().validate(ExplorationContentCatalog.new(chapter))
	for failure in failures: check(false,failure)
	var game := load("res://grayriver.tscn").instantiate() as GrayriverGame
	game.persistence_enabled=false
	root.add_child(game)
	current_scene=game
	for i in range(25): await process_frame
	game.ui.close_modal()
	GameRuntime.instance.set_process(false)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_DISABLED
	check(game.ready_for_play and game.save_slot==3 and game.save_section=="grayriver_frontier", "Frontier failed bootstrap or shares prototype save")
	check(game.current_data.authored_size==Vector2(9600,7200) and game.is_at_base(),"World footprint/town spawn wrong")
	check(game.active_enemies.size()==12 and not game.is_area_cleared(Vector2(-1500,350)),"Outdoor encounters or local clearing missing")
	var hp:=game.player.health_component.hp
	game.player.position=Vector2(-1600,350)
	check(not game.is_at_base(),"Wilderness counted as safe camp")
	game.player.position=Vector2(-3500,2100)
	check(game.is_at_base() and not game.has_hostiles_near(game.player.position),"Distant enemies block town services")
	var saved:=game.journey_location()
	check(saved.region=="camp" and saved.position==[-3500.0,2100.0],"Exact journey position unavailable")
	game.progress.journey=saved
	check(game.progress.validate_save_data(game.progress.serialize_save_data()),"New journey cannot serialize")
	check(not game.progress.validate_save_data({"journey":{"region":"camp","position":[NAN,0]}}),"Invalid journey coordinates accepted")
	var entrance: ExplorationExitData=game.current_data.exits[0]
	game._use_exit(entrance)
	for i in range(6): await process_frame
	check(game.region_id=="river_archive" and game.player.health_component.hp==hp,"Dungeon transition healed or failed")
	game._use_exit(game.current_data.exits[0])
	for i in range(6): await process_frame
	check(game.region_id=="camp" and game.player.position.distance_to(Vector2(-2600,-1660))<2,"Dungeon did not return to its geographic entrance")
	game.ui.close_modal()
	game.queue_free()
	current_scene=null
	for i in range(6): await process_frame
	if errors.is_empty(): print("Grayriver foundation passed: continuous authored world, content references, town boundary, isolated save/journey and geographic dungeon returns")
	quit(0 if errors.is_empty() else 1)
