extends "res://tests/support/input_scene_probe.gd"
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func tap(code: Key) -> void:
	await key(code,true);await key(code,false)
func boot_preview(path: String) -> MapPreviewGame:
	var preview:=load("res://demos/map_preview.tscn").instantiate() as MapPreviewGame
	preview.preview_scene=load(path) as PackedScene
	root.add_child(preview);current_scene=preview;game=preview
	while not preview.preview_ready: await process_frame
	await frames(4)
	return preview
func close_game() -> void:
	game.queue_free();current_scene=null
	await frames(6)
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self);game=await fixture.boot(true)
	game.progress.claims["test.formal.journey"]=true;game._save_progress()
	var original:=FileAccess.get_file_as_bytes("user://save_3.sav")
	await fixture.close()
	var preview:=await boot_preview("res://content/maps/grayriver/inn.tscn")
	check(game.region_id=="river_inn" and not game.progress.claims.has("test.formal.journey") and SaveManager.instance.repository is MemorySaveRepository,"Map preview read the formal journey or failed to isolate repository")
	var before:=game.player.position
	await key(KEY_D,true);await frames(15);await key(KEY_D,false)
	check(game.player.position.distance_to(before)>10 and not paused,"Preview did not accept real movement or paused the world")
	await tap(KEY_M);await capture("preview-local-map");await tap(KEY_ESCAPE)
	game.player.position=Vector2(0,350);await frames(5);await tap(KEY_F);await frames(6)
	check(game.region_id=="camp" and game.player.position.distance_to(Vector2(-4100,2960))<2,"Named exit did not return to its own outdoor landing")
	await tap(KEY_F5)
	game.player.health_component.hp=31
	await tap(KEY_F9);await frames(8)
	var memory:=SaveManager.instance.repository as MemorySaveRepository
	check(game.region_id=="camp" and game.player.health_component.hp>90 and memory!=null and not memory.snapshots.is_empty(),"Real F5/F9 did not restore the saved preview location/state")
	check(FileAccess.get_file_as_bytes("user://save_3.sav")==original,"Preview F5/F9 overwrote a formal save")
	await click("重置地图试玩");await frames(30);game=current_scene as MapPreviewGame
	preview=game as MapPreviewGame
	while not preview.preview_ready: await process_frame
	check(game.region_id=="river_inn" and not game.progress.claims.has("test.formal.journey"),"Preview reset lost the selected map or loaded formal state")
	await capture("preview-inn-start");await close_game()
	preview=await boot_preview("res://content/maps/grayriver/archive.tscn")
	check(game.region_id=="river_archive" and game.active_enemies.size()==3 and game.active_enemies.all(func(enemy):return enemy.can_process()),"Dungeon preview changed its encounter budget or disabled normal AI")
	await capture("preview-archive-start")
	game.player.position=Vector2(-850,0);await frames(4);await tap(KEY_F);await frames(6)
	check(game.region_id=="camp" and game.player.position.distance_to(Vector2(-2600,-1660))<2,"Dungeon's named return did not resolve to the outdoor anchor")
	await close_game()
	check(FileAccess.get_file_as_bytes("user://save_3.sav")==original,"Dungeon travel/reset leaked preview state into the formal file")
	game=await fixture.boot(true)
	check(game.progress.claims.has("test.formal.journey") and not SaveManager.instance.repository is MemorySaveRepository,"Returning to the formal journey retained preview repository or lost original progress")
	await fixture.close()
	if failures.is_empty(): print("PASS map preview input: real movement/M/F and F5/F9, correct named room/dungeon returns, selected-map reset, normal dungeon AI/budget, memory-only saves and exact formal file preservation/re-entry; controlled positions, no preview grants")
	quit(0 if failures.is_empty() else 1)
