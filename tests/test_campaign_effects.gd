extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=5) -> void:
	for i in range(n): await physics_frame; await process_frame
func entry(state: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in state.entries:
		if row.id==id: return row
	return {}
func run() -> void:
	var fixture:=Fixture.new(self)
	var game:=await fixture.boot(true)
	var actor:=game.player
	var buffs:=actor.get_node("BuffManager") as BuffManager
	var foe:=game.active_enemies[0]
	var foe_id:=foe.actor_context.id
	var store:=game.session.inventory
	store.receive("player","river_staff",1)
	var uid:=store.find_owned("player","river_staff"); store.equip("player",uid)
	store.set_properties(uid,{"coating":{"id":"fire_rag","expires_at":store.clock_seconds+60}})
	buffs.apply_buff(load("res://gameplay/abilities/data/burning.tres"),foe)
	buffs.apply_buff(load("res://content/spell_operations/statuses/toxin.tres"),foe)
	buffs.apply_buff(load("res://content/status/meal_fortitude.tres"),actor)
	buffs.apply_buff(load("res://content/status/guard_tonic.tres"),actor)
	buffs.tick(.4)
	actor.health_component.hp=75; actor.mana_component.mp=31
	actor.actor_context.actions.stamina.current=40
	actor.skill_manager._cooldowns["right"]=4.0
	actor.skill_manager.combinations.cooldowns["ignite"]=5.0
	actor.skill_manager.combinations.cooldown_durations["ignite"]=5.0
	actor.actor_context.martial.learn("staff_sweep"); actor.actor_context.martial.ready_at["staff_sweep"]=store.clock_seconds+6
	var state:=buffs.campaign_state(); var coating:=store.coating_state(uid)
	var original_magic:=float(entry(state,"burning").source_magic)
	check(BuffManager.valid_campaign_state(state),"Live timed effects cannot be serialized")
	game._save_progress(); await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	actor=game.player; buffs=actor.get_node("BuffManager") as BuffManager; store=game.session.inventory
	var restored:=buffs.campaign_state()
	for id in ["burning","poison","meal_fortitude","guard_tonic"]:
		var before:=entry(state,id); var after:=entry(restored,id)
		check(not after.is_empty() and float(after.remaining)<=float(before.remaining)+.001 and float(after.remaining)>float(before.remaining)-1,"Save/reentry erased or renewed effect: "+id)
	check(actor.health_component.hp==75 and actor.mana_component.mp==31,"Reload healed or refilled actual vitals")
	check(store.coating_state(uid)==coating and actor.actor_context.actions.stamina.current<=44,"Reload changed coating UID/expiry or refilled stamina")
	check(actor.skill_manager.combinations.cooldowns.get("ignite",0)>4 and actor.skill_manager._cooldowns.get("right",0)>3 and actor.actor_context.martial.reason("staff_sweep",actor.actor_context)=="武技尚在冷却","Reload cleared real cooldowns")
	check(entry(restored,"burning").source_id==foe_id and float(entry(restored,"burning").source_magic)==original_magic,"Reload lost damage identity/strength")
	foe=game.session.actor_for_id(foe_id) as Enemy
	foe.stats_component.intelligence=40; foe._apply_stats()
	var before_hp:=actor.health_component.hp
	var damage:=ActorCombatModel.incoming_damage(actor,5+int(original_magic*.3))+ActorCombatModel.incoming_damage(actor,3)
	buffs.tick(.6)
	check(before_hp-actor.health_component.hp==damage,"Periodic progress reset, ticked twice, or resampled caster strength")
	# F9 uses the same full restoration as a new process, including vitals/cooldowns.
	actor.skill_manager.combinations.cooldowns.clear(); actor.skill_manager._cooldowns.clear()
	game.reload_progress(); await frames()
	check(actor.health_component.hp==75 and actor.skill_manager.combinations.cooldowns.get("ignite",0)>4 and buffs.has_buff("poison"),"In-session reload differs from fresh load")
	var destination: String=game.catalog.regions.keys().filter(func(id): return id!="camp")[0]
	var remaining:=float(entry(buffs.campaign_state(),"burning").remaining)
	await fixture.travel(destination)
	check(buffs.has_buff("burning") and float(entry(buffs.campaign_state(),"burning").remaining)<=remaining and actor.skill_manager.combinations.cooldowns.get("ignite",0)>0,"Region travel cleansed effects or cooldowns")
	# Return a low-health authored actor with an outstanding actual toxin. Its
	# away-time death must use the regular death/claim/UID loot path after mounting.
	await fixture.travel("camp"); buffs.clear_all()
	foe=game.session.actor_for_id(foe_id) as Enemy
	var target_buffs:=foe.get_node("BuffManager") as BuffManager
	target_buffs.apply_buff(load("res://content/spell_operations/statuses/toxin.tres"),actor)
	foe.health_component.hp=1
	var weapon_uid:=str(store.equipped(foe_id).get(str(EquipmentData.SlotType.RIGHT_HAND),""))
	await fixture.travel(destination)
	store.clock_seconds+=4
	await fixture.travel("camp")
	check(game.session.actor_records[foe_id].dead and game.progress.claims.has(foe_id) and game.progress.loot_records.has(foe_id),"Unloaded DOT death did not commit world/loot facts")
	print("Away death inventory: "+JSON.stringify({"uid":weapon_uid,"item":store.item(weapon_uid).snapshot() if store.item(weapon_uid) else {},"location":store.locate(weapon_uid),"loot":game.progress.loot_records.get(foe_id,{})}))
	check(store.item(weapon_uid)!=null and store.locate(weapon_uid)==foe_id+".gear" and game.progress.loot_records[foe_id].equipment.get(store.item(weapon_uid).definition_id,0)==1,"Away-time corpse lost or replaced actual equipment UID")
	# Control recovery expires on its true timeline during a large advance.
	buffs.apply_buff(load("res://content/spell_operations/statuses/paralysis.tres"),actor)
	buffs.advance_campaign_time(10)
	check(not buffs.prevents_actions() and not buffs.is_immune("paralysis"),"Time jump extended control or its recovery window")
	var bad:=state.duplicate(true); bad.entries[0].remaining=INF
	check(not BuffManager.valid_campaign_state(bad),"Nonfinite effects accepted")
	bad=state.duplicate(true); bad.entries[0].path="res://core/game_runtime.gd"
	check(not BuffManager.valid_campaign_state(bad),"Non-Buff executable path accepted")
	game._save_progress(); await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	check(game.progress.claims.has(foe_id) and game.session.actor_for_id(foe_id)==null and game.progress.loot_records.has(foe_id),"Saved away-time death respawned or duplicated loot")
	# A real previous-version campaign has provisions but no complete effect map.
	buffs=game.player.get_node("BuffManager") as BuffManager
	buffs.apply_buff(load("res://content/status/meal_fortitude.tres"),game.player)
	buffs.tick(12)
	var legacy_remaining:=float(entry(buffs.campaign_state(),"meal_fortitude").remaining)
	game._save_progress()
	var section: String=game.save_section
	await fixture.close()
	var repository:=SaveRepository.new()
	var legacy:=repository.read("user://save_3.sav").data
	legacy.version=7
	for record: Dictionary in legacy.extensions[section].foundation.actors.values():
		record.erase("effects"); record.erase("cooldowns")
	var file:=FileAccess.open("user://save_3.sav",FileAccess.WRITE); file.store_var(legacy); file.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	buffs=game.player.get_node("BuffManager") as BuffManager
	var migrated:=entry(buffs.campaign_state(),"meal_fortitude")
	check(not migrated.is_empty() and float(migrated.remaining)<=legacy_remaining+.001 and float(migrated.remaining)>legacy_remaining-1,"V7 migration erased or refilled an actual food remainder")
	await fixture.close()
	if failures.is_empty(): print("PASS campaign effects: real save/F9/travel, vitals, periodic phase/source, personal buffs, cooldowns, unloaded toxin death/UID loot, control expiry and invalid records")
	quit(0 if failures.is_empty() else 1)
