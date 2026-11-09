extends SceneTree
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	if not ok: failures.append(text); push_error(text)
func run() -> void:
	var rules:=preload("res://content/foundation/frontier_rules.tres") as RulesetDefinition
	var session:=CampaignSession.new()
	root.add_child(session)
	session.configure(ExplorationContentCatalog.new(GrayriverDefinition.build()),rules)
	var store:=session.inventory
	store.ensure_actor("a"); store.ensure_actor("b")
	check(store.receive("a","river_sabre",2)==2,"Independent gear instances not granted")
	var rows:=store.entries("a.pack")
	check(rows.size()==2 and rows[0].uid!=rows[1].uid,"Identical equipment shares identity")
	store.swap_slots("a.pack", 0, 1)
	check(store.entries("a.pack")[0].uid == rows[1].uid and store.entries("a.pack")[1].uid == rows[0].uid, "Reordering changed the inventory identity")
	var first: String=rows[0].uid
	check(store.equip("a",first).accepted and store.count("a","river_sabre",true)==2 and store.count_in("a.pack","river_sabre")==1,"Equipping duplicated or removed another copy")
	var plan:=store.preview("a.gear","b.pack",first,1)
	check(store.commit(plan).accepted and store.item(first)!=null and store.locate(first)=="b.pack" and store.equipped("a").is_empty(),"Transfer changed UID or left ghost equipment")
	check(not store.commit(plan).accepted,"Stale transfer repeated")
	store.receive("a","ration",3)
	store.receive("b","crystal",2)
	var total:=store.count("a","ration")+store.count("b","ration")
	check(store.exchange("a","b",{"ration":2},{"crystal":1}).accepted,"Atomic barter rejected")
	check(store.count("a","ration")+store.count("b","ration")==total and store.count("a","crystal")==1,"Barter did not conserve inventory")
	var queued := store.preview("a.pocket", "a.pack", store.entries("a.pocket")[0].uid, 1)
	check(store.drop_pack("a", "camp", Vector2(10, 20)), "Owned pack could not be dropped")
	check(not store.commit(queued).accepted, "Drop failed to invalidate a transfer into the pack")
	check(store.recover_pack("a", "a.pack"), "Owner could not recover the dropped pack")
	var snapshot:=store.snapshot()
	check(not store.exchange("a","b",{"ration":99},{"crystal":1}).accepted and snapshot==store.snapshot(),"Failed barter mutated items")
	store.ensure_container("full.pack", "full", "pack", 1)
	store.ensure_container("full.pocket", "full", "pocket", 1)
	store.receive_into("full.pack", "river_sabre", 1)
	store.receive_into("full.pocket", "ration", 1)
	check(store.receive("full", "charcoal", 1) == 0, "Full inventory accepted a new material")
	# Pocket-only payment cannot access a deliberately stowed combat reagent.
	store.receive_into("a.pack","ward_powder",1)
	check(store.can_pay("a",{"ward_powder":1}) and not store.can_pay("a",{"ward_powder":1},true),"Combat cost reached into backpack")
	var before:=store.snapshot()
	store.begin_batch()
	store.pay("a",{"ration":1})
	store.restore_actor("a",before)
	store.end_batch(false)
	check(store.material_amounts("a")=={"ration":1,"crystal":1,"ward_powder":1},"Rollback changed item totals")
	# A full destination stack must merge without allocating an extra slot.
	store.ensure_container("c.pocket", "c", "pocket", 1)
	store.ensure_actor("c"); store.ensure_actor("d")
	store.receive("c","ration",2); store.receive("d","ration",2)
	var food_uid: String=store.entries("d.pocket")[0].uid
	check(store.commit(store.preview("d.pocket","c.pocket",food_uid,2)).accepted and store.entries("c.pocket").size()==1 and store.count("c","ration")==4,"Stack transfer exceeded full destination capacity")
	store.receive("c","clean_water",4)
	var water_uid: String=store.entries("c.pack")[0].uid
	check(store.commit(store.preview("c.pack","c.pocket",water_uid,1)).accepted==false,"Water bypassed full pocket")
	store.pay("c", {"ration": 4})
	check(store.commit(store.preview("c.pack","c.pocket",water_uid,1)).accepted and store.count("c","clean_water")==4,"Repacking water incorrectly reapplied the actor water cap")
	var public_copy:=store.item(first)
	public_copy.quantity=99
	check(store.item(first).quantity==1,"Query returned mutable authoritative item")
	var wrong:=store.snapshot()
	wrong.containers["b.pack"].items[0].quantity=2
	check(not store.valid_definitions(wrong),"Save accepted a stacked equipment instance")
	store.ensure_container("e.pack", "e", "pack", 1)
	store.ensure_container("f.pack", "f", "pack", 1)
	store.receive("e","river_sabre",1); store.receive("f","river_spear",1)
	var swap_uid:=store.find_owned("e","river_sabre")
	check(store.exchange("e","f",{"river_sabre":1},{"river_spear":1}).accepted and store.locate(swap_uid)=="f.pack","Full inventories could not barter gear without replacing its identity")
	var sequence:=session.facts.sequence
	check(not store.exchange("e","f",{"ration":1000},{}).accepted and session.facts.sequence==sequence,"Rejected trade published a committed fact")
	# Sale is a simultaneous exchange: both sides may need the outgoing slot.
	for owner in ["seller","buyer"]:
		store.ensure_container(owner+".pocket",owner,"pocket",1)
		store.ensure_container(owner+".pack",owner,"pack",1)
		store.ensure_actor(owner)
	store.receive_into("seller.pocket","ration",1)
	store.receive_into("seller.pack","river_sabre",1)
	store.receive_into("buyer.pocket","charcoal",1)
	store.receive_into("buyer.pack","coin",8)
	var sale_uid:=store.find_owned("seller","river_sabre")
	var sale_before:=store.snapshot()
	check(store.preview_trade_instance("buyer","seller",sale_uid,1,8).accepted and store.snapshot()==sale_before,"Full-pack sale preview rejected a valid exchange or mutated stock")
	check(store.trade_instance("buyer","seller",sale_uid,1,8).accepted and store.locate(sale_uid)=="buyer.pack" and store.count("seller","coin")==8 and store.count("buyer","coin")==0,"Full inventories could not sell an exact UID without a spare payment slot")
	var paid:=store.snapshot()
	check(not store.trade_instance("seller","buyer",sale_uid,1,9).accepted and store.snapshot()==paid,"Unaffordable sale did not roll back")
	# A different copy of the same item must never substitute for the selected UID.
	store.ensure_actor("copies"); store.ensure_actor("paying")
	store.receive("copies","river_staff",2); store.receive("paying","coin",24)
	var copies:=store.entries("copies.pack")
	var exact_uid: String=copies[1].uid
	check(store.trade_instance("paying","copies",exact_uid,1,8).accepted and store.locate(exact_uid)=="paying.pack" and store.locate(copies[0].uid)=="copies.pack","Sale substituted an earlier identical item")
	var saved:=store.snapshot()
	check(InventoryService.valid_snapshot(saved),"Canonical inventory cannot save")
	var invalid:=saved.duplicate(true)
	invalid.containers["a.pack"].items[0].quantity=-1
	check(not InventoryService.valid_snapshot(invalid),"Negative instance quantity accepted")
	var copy:=InventoryService.new(); copy.rules=rules; copy.definitions=store.definitions; copy.restore(saved)
	check(copy.snapshot()==saved and copy.item(first).definition_id=="river_sabre","Restoring changed physical item identity")
	session.queue_free()
	for i in range(4): await process_frame
	if failures.is_empty(): print("PASS foundation inventory: identity, atomic transfers/trades, capacity, combat access and snapshots")
	quit(0 if failures.is_empty() else 1)
