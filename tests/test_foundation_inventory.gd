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
	var snapshot:=store.snapshot()
	check(not store.exchange("a","b",{"ration":99},{"crystal":1}).accepted and snapshot==store.snapshot(),"Failed barter mutated items")
	store.containers["a.pack"].capacity=1
	store.containers["a.pocket"].capacity=1
	check(store.receive("a","charcoal",1)==0,"Full inventory accepted a new material")
	# Pocket-only payment cannot access a deliberately stowed combat reagent.
	store.containers["a.pack"].capacity=30
	store.receive_into("a.pack","ward_powder",1)
	check(store.can_pay("a",{"ward_powder":1}) and not store.can_pay("a",{"ward_powder":1},true),"Combat cost reached into backpack")
	var before:=store.snapshot()
	store.begin_batch()
	store.pay("a",{"ration":1})
	store.restore_actor("a",before)
	store.end_batch(false)
	check(store.material_amounts("a")=={"ration":1,"crystal":1,"ward_powder":1},"Rollback changed item totals")
	# A full destination stack must merge without allocating an extra slot.
	store.ensure_actor("c"); store.ensure_actor("d")
	store.containers["c.pocket"].capacity=1
	store.receive("c","ration",2); store.receive("d","ration",2)
	var food_uid: String=store.entries("d.pocket")[0].uid
	check(store.commit(store.preview("d.pocket","c.pocket",food_uid,2)).accepted and store.entries("c.pocket").size()==1 and store.count("c","ration")==4,"Stack transfer exceeded full destination capacity")
	store.receive("c","clean_water",4)
	var water_uid: String=store.entries("c.pack")[0].uid
	check(store.commit(store.preview("c.pack","c.pocket",water_uid,1)).accepted==false,"Water bypassed full pocket")
	store.containers["c.pocket"].capacity=2
	check(store.commit(store.preview("c.pack","c.pocket",water_uid,1)).accepted and store.count("c","clean_water")==4,"Repacking water incorrectly reapplied the actor water cap")
	var public_copy:=store.item(first)
	public_copy.quantity=99
	check(store.item(first).quantity==1,"Query returned mutable authoritative item")
	var wrong:=store.snapshot()
	wrong.containers["b.pack"].items[0].quantity=2
	check(not store.valid_definitions(wrong),"Save accepted a stacked equipment instance")
	store.ensure_actor("e"); store.ensure_actor("f")
	store.containers["e.pack"].capacity=1; store.containers["f.pack"].capacity=1
	store.receive("e","river_sabre",1); store.receive("f","river_spear",1)
	var swap_uid:=store.find_owned("e","river_sabre")
	check(store.exchange("e","f",{"river_sabre":1},{"river_spear":1}).accepted and store.locate(swap_uid)=="f.pack","Full inventories could not barter gear without replacing its identity")
	var sequence:=session.facts.sequence
	check(not store.exchange("e","f",{"ration":1000},{}).accepted and session.facts.sequence==sequence,"Rejected trade published a committed fact")
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
