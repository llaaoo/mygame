extends SceneTree
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=3) -> void:
	for i in range(n): await process_frame
func make_ready(store: InventoryService,key: String) -> void:
	var uid:=store.find_owned("player",key)
	if uid.is_empty() or store.locate(uid)=="player.pocket": return
	if store.space("player.pocket",key)<=0:
		var row:=store.entries("player.pocket")[0]
		check(store.commit(store.preview("player.pocket","player.pack",row.uid,row.quantity)).accepted,"Fixture could not stow a material to ready an actual item")
	check(store.commit(store.preview(store.locate(uid),"player.pocket",uid,store.item(uid).quantity)).accepted,"Fixture could not ready actual item: "+key)
func run() -> void:
	var fixture:=Fixture.new(self)
	var game:=await fixture.boot(true)
	var actor:=game.player
	var context:=actor.actor_context
	var store:=game.session.inventory
	actor.position=TownServices.POINT
	store.receive("player","river_sabre",2)
	var copies:=store.entries("player.pack").filter(func(row): return row.definition=="river_sabre")
	var uid: String=copies[0].uid
	var other: String=copies[1].uid
	store.set_properties(uid,{"coating":{"id":"fire_rag","expires_at":store.clock_seconds+60}})
	var stock:=store.snapshot_owners([TownServices.MERCHANT])
	game.town_services.ensure_stock()
	check(stock==store.snapshot_owners([TownServices.MERCHANT]),"Opening service refilled finite stock")
	check(game.town_services.transact(uid,true).accepted and store.locate(uid)==TownServices.MERCHANT+".pack" and store.locate(other)=="player.pack" and store.coating(uid)!=null,"Selling replaced the selected UID or coating")
	store.receive("player","coin",60)
	check(game.town_services.transact(uid,false).accepted and store.locate(uid)=="player.pack","Buying did not return the same actual UID")
	store.receive("player","metal_scrap",12)
	var immutable:=store.definitions.river_sabre as EquipmentData
	var attack:=float(immutable.stat_modifiers.attack_damage)
	check(game.town_services.salvage(uid,true).accepted and store.item(uid).properties.upgrade_level==1 and store.coating(uid)!=null,"Upgrade did not preserve specific gear/coating")
	check(store.equipment_definition(uid).stat_modifiers.attack_damage==attack+1 and immutable.stat_modifiers.attack_damage==attack,"Upgrade mutated shared definition or has no real effect")
	store.equip("player",uid)
	check(actor.get_node("EquipmentManager").get_equipment(6).display_name.ends_with("+1"),"Worn upgrade is cosmetic only")
	var before:=store.snapshot()
	check(not game.town_services.salvage(uid,false).accepted and before==store.snapshot(),"Equipped gear could be dismantled")
	store.unequip("player",6)
	check(game.town_services.salvage(other,false).accepted and store.item(other)==null and store.item(uid)!=null,"Dismantling destroyed the wrong physical copy")
	# Full buyer cannot pay and lose the object, and replaying a sale cannot duplicate it.
	store.ensure_actor("full")
	for container in store.actor_containers("full"):
		store._containers[container].capacity=1 # Controlled capacity fixture, no runtime UI write.
	store.receive_into("full.pocket","coin",100)
	store.receive_into("full.pack","river_staff",1)
	before=store.snapshot()
	check(not store.trade_instance("full","player",uid,1,10).accepted and before==store.snapshot(),"Rejected purchase partly charged or moved the gear")
	check(not store.trade_instance("full","player",uid,2,10).accepted and before==store.snapshot(),"Invalid instance quantity mutated inventory")
	# Renewable world source feeds a discovered recipe, then actual ammunition.
	var source: ExplorationInteractable
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.has_meta("survival_station") and node.get_meta("survival_station").id=="resource.fallen_wood": source=node
	check(source!=null,"Renewable raw material source was never mounted")
	actor.position=source.position
	var charcoal:=store.count("player","charcoal")
	game.survival.inspect(source,source.get_meta("survival_station"))
	check(actor.field_work.start_selected(),"Actual resource node could not be harvested")
	actor.field_work.tick(3)
	check(store.count("player","charcoal")==charcoal+2 and game.survival.needs.harvests.has("resource.fallen_wood"),"Harvest did not enter persistent inventory/regrowth")
	game.survival.inspect(source,source.get_meta("survival_station"))
	check(not actor.field_work.start_selected(),"Repeated gathering bypassed world regeneration")
	actor.field_work.close_panel()
	for note in game.current_data.discoveries:
		if note.id=="river.handbook":
			actor.position=note.pos
			check(game.progress_service.discover(note),"Could not learn town recipes from actual handbook")
	var supplies:=game.survival.supplies
	check(supplies.knows_recipe("arrows") and supplies.craft("arrows") and store.count("player","arrow")==6,"Gathered/dismantled material did not produce real ammunition")
	actor.position=TownServices.POINT
	# Learning from actual book: cancellation and duplicate knowledge do not consume it.
	store.receive("player","book_spear_thrust",2)
	var books:=store.count("player","book_spear_thrust")
	check(context.item_actions.begin("book_spear_thrust"),"Book action is not reachable")
	context.item_actions.cancel()
	check(store.count("player","book_spear_thrust")==books and not context.martial.learned.has("spear_thrust"),"Cancelled reading granted knowledge or lost book")
	check(context.item_actions.begin("book_spear_thrust") and context.item_actions.commit(),"Book failed to teach a physical technique")
	check(context.martial.learned.has("spear_thrust") and store.count("player","book_spear_thrust")==books-1 and not context.item_actions.begin("book_spear_thrust"),"Known technique consumed duplicate book")
	# Same-category potion buffs replace, are finite, and food has a combat contribution.
	var buffs:=actor.get_node("BuffManager") as BuffManager
	store.receive("player","guard_tonic",1); store.receive("player","clear_tonic",1)
	make_ready(store,"guard_tonic"); make_ready(store,"clear_tonic")
	check(context.item_actions.begin("guard_tonic") and context.item_actions.commit() and buffs.has_buff("guard_tonic") and is_equal_approx(buffs.get_damage_taken_multiplier(),.85),"Potion did not use the common status pipeline")
	check(context.item_actions.begin("clear_tonic") and context.item_actions.commit() and buffs.has_buff("clear_tonic") and not buffs.has_buff("guard_tonic") and buffs.is_immune("poison"),"Potions stacked mutually exclusive tactical benefits")
	store.receive("player","ration",1)
	make_ready(store,"ration")
	var endurance: int=actor.get_node("StatsComponent").effective_stat("endurance")
	game.survival.begin_eating("ration"); actor.field_work.tick(2)
	check(buffs.has_buff("meal_fortitude") and actor.get_node("StatsComponent").effective_stat("endurance")==endurance+2,"Real food supplied no physical combat buff")
	buffs.tick(10)
	var remaining: float=buffs.provision_state()[0].remaining
	# A safe rest advances hours, real coating expiry, provisions and regrowth together.
	var rest: ExplorationInteractable
	for node in game.region_root.get_children():
		if node is ExplorationInteractable and node.get_meta("survival_rest",false): rest=node
	actor.position=rest.position
	store.receive("player","ration",4)
	store.receive("player","clean_water",4)
	game.survival.needs.fatigue=80
	game.survival.needs.harvests["resource.fallen_wood"]=200.0
	var time_before:=store.clock_seconds
	game.survival.inspect_rest(rest)
	actor.field_work.selected=1 # Three game hours, 3.2 presentation seconds.
	check(actor.field_work.start_selected(),"Hour-based rest refused safe camp/provisions")
	actor.field_work.tick(1)
	actor.field_work.cancel("test")
	check(absf(store.clock_seconds-time_before)<.1 and store.coating(uid)!=null,"Interrupted rest advanced time or expired coating")
	game.survival.inspect_rest(rest); actor.field_work.selected=1
	var rations:=store.count("player","ration")
	var water:=store.count("player","clean_water")
	check(actor.field_work.start_selected(),"Restarted rest refused")
	actor.field_work.tick(4)
	check(absf(store.clock_seconds-time_before-180)<.2 and WorldTime.instance.get_hour()>=11,"Rest failed to advance selected world hours")
	check(store.count("player","ration")==rations-1 and store.count("player","clean_water")==water-1 and game.survival.needs.fatigue<=35,"Rest did not charge real provisions or reduce fatigue")
	check(store.coating(uid)==null and not buffs.has_buff("clear_tonic") and is_equal_approx(game.survival.needs.harvests["resource.fallen_wood"],20),"Rest refilled timed effects or failed to advance regeneration")
	check(remaining<90,"Potion time did not expire normally before rest")
	# Crossing midnight changes day and NPC availability; hostile status rejects sleep.
	store.clock_seconds=(21.5-8)*60
	var npc:=game.session.actor_for_id("river.enemy.service.trainer") as ServiceNPC
	check(npc.actor_context.actions.try_action(Action.melee(npc)).accepted,"NPC could not enter physical windup before time skip")
	game.session.advance_rest_time(60)
	check(npc.actor_context.actions.mode=="idle","Time skip left an hours-old physical windup alive")
	check(not npc.working and npc.position==npc.locations.rest,"Rest time did not update trainer schedule")
	game.session.advance_rest_time(120)
	check(WorldTime.instance.day()==2 and WorldTime.instance.get_hour()<1,"24-hour clock did not cross day boundary")
	buffs.apply_buff(load("res://gameplay/abilities/data/poison.tres"))
	game.survival.inspect_rest(rest)
	check(not actor.field_work.start_selected(),"Poisoned actor bypassed safe-rest gate")
	actor.field_work.close_panel(); buffs.remove_status("poison")
	# Physical save/reentry preserves identities, upgrade, knowledge and buff remainder.
	make_ready(store,"ration")
	game.survival.begin_eating("ration"); actor.field_work.tick(2)
	buffs.apply_buff(load("res://content/status/guard_tonic.tres")); buffs.tick(14)
	actor.health_component.hp=actor.health_component.max_hp
	var saved_health:=actor.health_component.hp
	var clock:=store.clock_seconds
	game._save_progress()
	await fixture.close()
	var boot_started:=Time.get_ticks_msec()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	var boot_seconds:=(Time.get_ticks_msec()-boot_started)/1000.0
	store=game.session.inventory; actor=game.player
	check(store.item(uid)!=null and store.item(uid).properties.upgrade_level==1 and actor.actor_context.martial.learned.has("spear_thrust"),"Save/reentry lost gear or knowledge")
	check(store.clock_seconds>=clock and store.clock_seconds<clock+boot_seconds+1 and WorldTime.instance.day()==2,"Save/reentry reset persistent time or advanced beyond real boot time")
	var restored: Array=actor.get_node("BuffManager").provision_state()
	var tonic: Array=restored.filter(func(entry): return entry.id=="guard_tonic")
	check(restored.size()==2 and tonic.size()==1 and tonic[0].remaining<=76 and tonic[0].remaining>73,"Save/reentry refilled potion duration")
	check(actor.health_component.hp==saved_health and actor.health_component.max_hp>=saved_health and saved_health>100,"Save/reentry clamped food-boosted health before restoring its buff")
	var invalid:=game.session.snapshot(); invalid.actors.player.martial.ready_at={"blade_breaker":NAN}
	check(not CampaignSession.valid_snapshot(invalid),"Invalid physical cooldown accepted from save")
	await fixture.close()
	if failures.is_empty(): print("PASS system depth: finite UID economy, upgrades, knowledge, timed provisions, rest/day/schedules and actual save/reentry")
	quit(0 if failures.is_empty() else 1)
