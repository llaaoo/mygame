extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
class OptionalModule extends SaveRecord:
	@export_storage var surveyed: Dictionary={}
	@export_storage var budget := 4
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	# An actual checked-in historical game save, not a current snapshot relabelled v9.
	var historic:="res://docs/reviews/senior-first-play-2026-11-08/evidence/final-normal-save_3.sav"
	var original:=FileAccess.get_file_as_bytes(historic)
	var file:=FileAccess.open("user://save_3.sav",FileAccess.WRITE);file.store_buffer(original);file.close()
	var fixture:=Fixture.new(self);var game:=await fixture.boot(true)
	check(SaveManager.instance.last_read.usable() and not game.progress.foundation.is_empty(),"Real historical save did not migrate")
	var record:=game.session.inventory.snapshot()
	var module:=OptionalModule.new();module.surveyed={"river_inn":true};module.budget=7
	game.session.save_sections.register("test.cartography",module)
	await fixture.travel("river_inn")
	var storage:=game.current_data.storage[0] as WorldStorageData
	game.player.position=storage.pos+Vector2(0,25)
	var store:=game.session.inventory
	# Historical pockets may be full. Move their real contents into the new chest.
	for row in store.entries("player.pocket"):
		check(game.world_storage.transfer(storage,row.uid,row.quantity,storage.id).accepted,"Historical pocket could not be safely stored")
	check(store.receive("player","resin_sprayer",1)==1,"Used item fixture has no real capacity")
	var uid: String=store.entries("player.pocket").filter(func(row: Dictionary):return row.definition=="resin_sprayer")[0].uid
	check(store.spend_instance("player",uid,"doses",1) and game.world_storage.transfer(storage,uid,1,storage.id).accepted,"Could not create an actual persistent used instance")
	game._save_progress()
	var expected:=store.entries(storage.id);var private_id:=storage.id
	var data:=SaveManager.instance.read_extension(3,game.save_section)
	check(data.foundation.__versions.production==1 and data.foundation.__versions["test.cartography"]==1 and data.foundation["test.cartography"].budget==7,"Actual session modules were not versioned independently")
	check(data.foundation.inventory.containers.has(private_id) and record.next_uid<=data.foundation.inventory.next_uid,"Upgrade lost real inventory or rewound UID allocation")
	await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true)
	check(game.region_id=="river_inn" and game.session.inventory.entries(private_id)==expected and game.session.inventory.item(uid).properties.doses==2,"Actual modular reload changed room/UID/doses")
	# This module is currently absent, but another ordinary save must retain it.
	game._save_progress();data=SaveManager.instance.read_extension(3,game.save_section)
	check(data.foundation["test.cartography"].surveyed.river_inn and data.foundation["test.cartography"].budget==7,"An unloaded campaign module was silently erased")
	var all:=SaveManager.instance.read_slot(3).data
	all.extensions[game.save_section].foundation.__versions.production=2
	file=FileAccess.open("user://save_3.sav",FileAccess.WRITE);file.store_var(all);file.close()
	var protected_bytes:=FileAccess.get_file_as_bytes("user://save_3.sav")
	var actor:=game.player;var before:=game.session.inventory.snapshot()
	game.reload_progress()
	check(SaveManager.instance.last_read.status==SaveRepository.Status.UNSUPPORTED_VERSION and game.player==actor and game.session.inventory.snapshot()==before,"F9 partially loaded a newer nested module or fell back to an older backup")
	check(not SaveManager.instance.save_game(3) and FileAccess.get_file_as_bytes("user://save_3.sav")==protected_bytes,"Autosave overwrote a newer nested module")
	await fixture.close()
	if failures.is_empty():print("PASS modular campaign save: actual historical migration, real NPC/service state and persistent used item in interior, unknown nested module retention across re-entry/save, UID allocator and future nested module F9/autosave protection")
	quit(0 if failures.is_empty() else 1)
