extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func run() -> void:
 var fixture:=Fixture.new(self)
 var game: GrayriverGame=await fixture.boot(true)
 var actor:=game.player
 var store:=game.session.inventory
 var actions:=game.inventory_actions
 var point:=actor.position
 # A full backpack still permits a real exchange, but cannot absorb an unequipped item.
 store.receive("player","river_sabre",actor.actor_context.rules.pack_capacity)
 var weapon:=store.find_owned("player","river_sabre")
 check(actions.equip(weapon).accepted,"Full-pack equipping failed to use freed incoming slot")
 store.receive("player","river_sabre",1)
 check(store.entries("player.pack").size()==actor.actor_context.rules.pack_capacity,"Pack fixture was not full")
 check(not actions.unequip(EquipmentData.SlotType.RIGHT_HAND).accepted and weapon in store.equipped("player").values(),"Full-pack unequip removed or lost the equipped item")
 var second:=store.find_owned("player","river_sabre")
 check(actions.equip(second).accepted and second in store.equipped("player").values() and store.locate(weapon)=="player.pack","Full-pack exchange did not preserve both UIDs")
 # Dropping equipped gear to the world does not need a free pack slot.
 store.set_properties(second,{"coating":{"id":"fire_rag","expires_at":store.clock_seconds+30}})
 check(actions.drop(second,1).accepted and store.equipped("player").is_empty(),"Full-pack gear drop was blocked or left ghost equipment")
 var ground:=store.locate(second)
 check(ground.begins_with("ground.") and game.session._ground_nodes.has(ground) and store.coating(second)!=null,"Drop did not mount a real, coated instance")
 check(not actions.take(ground,second,1).accepted and store.locate(second)==ground,"Full pickup duplicated or destroyed the ground item")
 check(actions.drop(weapon,1).accepted,"Dropping from a full bag failed")
 var freed:=store.entries("player.pack").size()
 check(actions.take(ground,second,1).accepted and store.locate(second)=="player.pack" and store.entries("player.pack").size()==freed+1,"Pickup did not restore the same UID into freed space")
 # Splitting preserves quantities and metadata, allocates a new identity, and respects space.
 store.receive("player","charcoal",12)
 var coal:=store.ready_uid("player","charcoal")
 var before:=store.item(coal).quantity
 var split:=actions.split(coal,3)
 check(split.accepted and split.item_uids[0]!=coal and store.item(coal).quantity==before-3 and store.item(split.item_uids[0]).quantity==3,"Stack split lost quantity or reused the original UID")
 var snapshot:=store.snapshot()
 check(not actions.drop(coal,100000).accepted and store.snapshot()==snapshot,"Invalid drop mutated the inventory")
 check(not actions.split(coal,0).accepted and store.snapshot()==snapshot,"Invalid split mutated the inventory")
 check(actions.drop(coal,2).accepted,"Partial-stack drop failed")
 var found_quantity:=0
 for id in store.ground_ids(game.region_id):
  for row in store.entries(id):
   if row.definition=="charcoal": found_quantity+=row.quantity
 check(found_quantity==2 and store.count("player","charcoal")==10,"Partial drop did not conserve material count")
 # Per-instance spray doses and timed coatings survive real ground transfers and saves.
 store.receive("player","venom_sprayer",1)
 var bottle:=store.ready_uid("player","venom_sprayer")
 check(store.spend_instance("player",bottle,"doses",1),"Bottle fixture did not pay a real dose")
 actor.skill_manager.shortcuts.bind_item("quick_e","venom_sprayer",bottle)
 check(actions.drop(bottle,1).accepted,"Partly-used bottle failed to drop")
 var bottle_ground:=store.locate(bottle)
 check(not QuickslotView.item_state(actor,actor.skill_manager.shortcuts.binding("quick_e")).ready,"Dropped bound bottle remained usable")
 var original_clock:=store.clock_seconds
 check(actions.equip(second).accepted,"Coated weapon could not be re-equipped")
 check(actions.drop(second,1).accepted,"Coated weapon could not be dropped again")
 var weapon_ground:=store.locate(second)
 await fixture.travel("river_mine")
 check(not game.session._ground_nodes.has(bottle_ground) and store.locate(bottle)==bottle_ground,"Leaving the region retained world nodes or lost cached stock")
 await fixture.travel("camp",point)
 check(game.session._ground_nodes.has(bottle_ground),"Region return failed to mount ground stock")
 game._save_progress()
 check(FileAccess.file_exists(SaveManager.instance._path(3)),"Save was not written")
 await fixture.close()
 fixture=Fixture.new(self); game=await fixture.boot(true)
 actor=game.player; store=game.session.inventory; actions=game.inventory_actions
 check(store.locate(bottle)==bottle_ground and int(store.item(bottle).properties.doses)==2,"Save/re-entry replaced a bottle UID or refilled it")
 check(store.locate(second)==weapon_ground and store.coating(second)!=null and float(store.item(second).properties.coating.expires_at)<=original_clock+30.01,"Save/re-entry refreshed a coating or replaced its UID")
 check(game.session._ground_nodes.has(bottle_ground),"Saved ground cache was not remounted")
 actor.position=point+Vector2(300,0)
 snapshot=store.snapshot()
 check(not actions.take(bottle_ground,bottle,1).accepted and store.snapshot()==snapshot,"Remote ground pickup accepted or changed stock")
 actor.position=point
 check(actions.take(bottle_ground,bottle,1).accepted and int(store.item(bottle).properties.doses)==2,"Picking up a partial bottle refilled it")
 check(QuickslotView.item_state(actor,actor.skill_manager.shortcuts.binding("quick_e")).ready,"Same-UID pickup did not restore the existing shortcut")
 check(game.session.drop_pack("player"),"Pack could not be dropped")
 check(not actions.transfer(bottle,"player.pack",1).accepted,"Dropped pack accepted a remote transfer")
 check(not actions.take(weapon_ground,second,1).accepted,"Gear was remotely placed into a detached pack")
 var malformed:=store.snapshot(); malformed.containers[bottle_ground].position=[INF,0]
 check(not InventoryService.valid_snapshot(malformed),"Non-finite ground location accepted")
 check(InventoryService.valid_snapshot(store.snapshot()) and store.valid_definitions(store.snapshot()),"Live persisted inventory violates its schema")
 await fixture.close()
 if failures.is_empty(): print("PASS inventory lifecycle: full-pack swap/drop/pickup, exact quantities, split identities, capacity/range/stale rejection, real save/re-entry, bottle doses, coating clocks, ground remount and detached pack")
 quit(0 if failures.is_empty() else 1)
