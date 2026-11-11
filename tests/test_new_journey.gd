extends "res://tests/support/input_scene_probe.gd"
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
class FaultRepository extends SaveRepository:
	var fail_at := ""
	func _write_file(path: String,data: Dictionary) -> Error:
		return ERR_CANT_CREATE if fail_at=="archive" and path.ends_with("latest.sav") or fail_at=="stage" and path.ends_with(".new.tmp") else super._write_file(path,data)
	func _replace_file(source: String,destination: String) -> Error:
		if fail_at=="backup" and source.ends_with(".new.bak.tmp") or fail_at=="primary" and source.ends_with(".new.tmp"): return ERR_CANT_CREATE
		return super._replace_file(source,destination)
func payload(id: String) -> Dictionary:
	var root_data:=SaveData.Root.new()
	root_data.meta=SaveData.MetaData.new(); root_data.player=SaveData.PlayerData.new(); root_data.world=SaveData.WorldData.new(); root_data.quest=SaveData.QuestSave.new()
	root_data.extensions={"test":{"id":id}}
	return root_data.serialize()
func run() -> void:
	root.size=Vector2i(1152,648)
	# Every ordinary I/O failure leaves the active previous game recoverable.
	for fail_at in ["archive","stage","backup","primary"]:
		var path: String="user://restart-"+fail_at+".sav"
		var repository:=FaultRepository.new()
		check(repository.write(path,payload("older")) and repository.write(path,payload("current")),"Restart fault fixture failed")
		var primary:=FileAccess.get_file_as_bytes(path); var backup:=FileAccess.get_file_as_bytes(path+".bak")
		repository.fail_at=fail_at
		check(repository.start_new(path,payload("fresh"),payload("unsaved")).is_empty(),"Failed restart reported success: "+fail_at)
		check(FileAccess.get_file_as_bytes(path)==primary and FileAccess.get_file_as_bytes(path+".bak")==backup,"Restart fault changed old primary/backup: "+fail_at)
	var repository:=SaveRepository.new(); var path: String="user://restart-ok.sav"
	repository.write(path,payload("old")); repository.write(path,payload("newer"))
	var archive:=repository.start_new(path,payload("fresh"),payload("unsaved"))
	check(not archive.is_empty() and repository.read(archive.path_join("latest.sav")).data.extensions.test.id=="unsaved","Restart did not archive latest memory")
	var invalid:=FileAccess.open(path,FileAccess.WRITE); invalid.store_var("damaged"); invalid.close()
	check(repository.read(path).status==SaveRepository.Status.RECOVERED and repository.read(path).data.extensions.test.id=="fresh","New backup resurrected the previous journey")
	# Product confirmation/cancel and scene replacement use actual mouse input.
	var fixture:=Fixture.new(self)
	game=await fixture.boot(true)
	var player:=game.player; var stock:=game.session.inventory
	var starting:=stock.snapshot_owners(["player"])
	check(ControlPreferences.set_quick_cast(false),"Could not save control preference")
	var preference_bytes:=FileAccess.get_file_as_bytes(ControlPreferences.PATH)
	var foe:=game.active_enemies[0]
	var foe_id: String=foe.actor_context.id
	var foe_weapon: String=str(stock.equipped(foe_id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	CombatExecutor.report_hit(player,foe,10000,foe.position,null,["physical"])
	await frames(3)
	check(game.progress.claims.has(foe_id) and game.progress.loot_records.has(foe_id),"Old journey did not contain an actual defeated enemy")
	player.stats_component.attribute_points=8
	game.progress.claim("test.previous","旧旅程","must disappear",["water_call"],["fire_sigil_fireball"])
	game.progress.waypoint={"position":[123,456]}; game.progress.choices["river.rehearsal"]="yes"
	stock.receive("player","river_staff",1); stock.receive("player","coin",32)
	var old_uid:=stock.find_owned("player","river_staff"); stock.equip("player",old_uid)
	stock.set_properties(old_uid,{"coating":{"id":"fire_rag","expires_at":stock.clock_seconds+60}})
	player.actor_context.martial.learn("staff_sweep"); player.skill_manager.shortcuts.bind_technique("quick_e","staff_sweep")
	(player.get_node("BuffManager") as BuffManager).apply_buff(load("res://content/spell_operations/statuses/toxin.tres"),player)
	stock.clock_seconds+=100
	check(game.session.production.start("town.arrows").accepted,"Restart production fixture failed")
	game._save_progress()
	var independent: String="user://save_2.sav"; repository.write(independent,payload("independent"))
	var independent_bytes:=FileAccess.get_file_as_bytes(independent)
	game.show_valley_pause(); await frames(6)
	await click("重新开始灰河谷"); await capture("new-journey-confirm")
	await click("取消，继续当前旅程")
	check(game.progress.claims.has("test.previous") and stock.item(old_uid)!=null,"Cancel reset progress or inventory")
	game.show_valley_pause(); await frames(6); await click("重新开始灰河谷")
	var previous_instance:=game.get_instance_id()
	await click("归档旧旅程并重新开始")
	for i in range(180):
		await frames(1)
		var current:=current_scene as GrayriverGame
		if current and current.get_instance_id()!=previous_instance and current.ready_for_play and not current._restarting:
			game=current; break
	check(is_instance_valid(game) and game.get_instance_id()!=previous_instance and game.ready_for_play,"New scene did not start")
	if not is_instance_valid(game): quit(1); return
	player=game.player; stock=game.session.inventory
	check(not game.progress.claims.has("test.previous") and not game.progress.actions.has("water_call") and game.progress.waypoint.is_empty() and not game.progress.choices.has("river.rehearsal"),"Restart retained old knowledge/world state")
	check(player.stats_component.level==1 and player.stats_component.attribute_points==0 and player.actor_context.martial.learned.is_empty(),"Restart retained growth or martial knowledge")
	check(not player.actor_context.magic.awakened and not player.actor_context.magic.legacy_exempt and player.mana_component.max_mp==0 and player.mana_component.mp==0,"Restart imported fresh progress as a legacy awakened traveler")
	check(stock.item(old_uid)==null and stock.count("player","coin")==0 and (player.get_node("BuffManager") as BuffManager).campaign_state().entries.is_empty(),"Restart retained old equipment, money or effects")
	check(game.session.production.snapshot().jobs.is_empty(),"Restart retained old production orders")
	check(stock.clock_seconds<10 and game.is_at_base() and player.actor_context.actions.mode=="idle","Restart retained old time/location/action")
	check(player.skill_manager.shortcuts.binding("quick_e").get("kind","")!="technique" and player.skill_manager.combinations.cooldowns.is_empty(),"Restart retained bindings or cooldowns")
	var fresh:=stock.snapshot_owners(["player"])
	check(fresh.containers==starting.containers,"Fresh player supplies/gear differ from an original new game")
	check(FileAccess.get_file_as_bytes(independent)==independent_bytes,"Restart changed the independent prison slot")
	check(FileAccess.get_file_as_bytes(ControlPreferences.PATH)==preference_bytes and not ControlPreferences.quick_cast,"Restart erased control preferences")
	foe=game.session.actor_for_id(foe_id) as Enemy
	check(is_instance_valid(foe) and not foe.health_component.is_dead and foe.health_component.hp==foe.health_component.max_hp and foe.rewards_enabled,"Restart did not restore authored enemy and rewards")
	check(not game.progress.claims.has(foe_id) and not game.progress.loot_records.has(foe_id) and stock.item(foe_weapon)!=null and stock.locate(foe_weapon)==foe_id+".gear","Restart retained old corpse/claim or lost original equipment")
	await capture("new-journey-fresh-arrival")
	game.ui.close_modal(); game._save_progress()
	game.reload_progress(); await frames(10)
	check(not game.progress.claims.has("test.previous") and stock.item(old_uid)==null,"Reload resurrected the archived journey")
	check(not game.player.actor_context.magic.awakened and game.player.mana_component.max_mp==0,"Reload of a freshly restarted journey granted magic")
	var archived:=DirAccess.open("user://journey_archive")
	check(archived!=null and archived.get_directories().size()>0,"No journey archive exists")
	game.ui.close_modal(); game.queue_free(); current_scene=null; await frames(6)
	if failures.is_empty(): print("PASS new journey: archive/write/replace failures, fresh backup recovery, actual confirm/cancel/reload, default growth/inventory/world/time and independent slot")
	quit(0 if failures.is_empty() else 1)
