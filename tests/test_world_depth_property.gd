extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot(true,true)
	var store:=game.session.inventory;var law:=game.session.law;var merchant:=TownServices.MERCHANT
	var spec: WorldStorageData
	for box in game.current_data.storage:
		if box.id=="storage.town.merchant.sealed":spec=box
	check(spec!=null,"Authored private source missing")
	game.player.position=spec.pos+Vector2(0,-30)
	var witnesses:=game.session.property_witnesses("player",spec.pos)
	check(witnesses.has(merchant),"Nearby actual owner failed to witness open private source")
	store.receive("player","metal_scrap",1)
	var row: Dictionary=store.entries(spec.id).filter(func(entry):return entry.definition=="metal_scrap")[0]
	var uid: String=row.uid;var original:=store.count("player","metal_scrap")
	check(game.world_storage.transfer(spec,uid,1,"player.pack").accepted,"Private source explicit transfer failed")
	var cases:=law.pending(merchant);check(cases.size()==1 and cases[0].reported and law.has_reported_debt("player"),"Actual witness produced no service consequence")
	var case_id: String=cases[0].id;var tagged:=store.with_property("property_case",case_id)
	check(tagged.size()==1 and tagged[0].quantity==1 and store.count("player","metal_scrap")==original+1 and store.clean_count("player","metal_scrap")==original,"Partial theft merged tags into clean inventory")
	var stolen_uid: String=tagged[0].uid
	check(not game.town_services.reason().is_empty() and not store.trade_instance(merchant,"player",stolen_uid,1,2).accepted,"Reported theft bypassed service/instance sale restrictions")
	var snapshot:=game.session.snapshot();check(CampaignSession.valid_snapshot(snapshot),"Tagged actual inventory failed its own save validator")
	var invalid:=snapshot.duplicate(true);invalid.law.cases.clear()
	check(not CampaignSession.valid_snapshot(invalid),"Orphan property-case reference accepted")
	invalid=snapshot.duplicate(true);invalid.law.next_case=1
	check(not CampaignSession.valid_snapshot(invalid),"Colliding future case ID accepted")
	game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true);store=game.session.inventory;law=game.session.law
	check(law.has_reported_debt("player") and store.item(stolen_uid)!=null,"Cold save lost legal ownership/actual UID")
	var purse:=store.count(merchant,"coin");store.receive("player","coin",20);var coins:=store.count("player","coin");var fine: int=law.cases[case_id].fine
	check(law.compensate(case_id).accepted and not law.compensate(case_id).accepted and not law.has_reported_debt("player") and store.item(stolen_uid).properties.get("property_case","").is_empty(),"Compensation failed exact receipt/tag lifecycle")
	check(store.count("player","coin")==coins-fine and store.count(merchant,"coin")==purse+fine,"Compensation minted/lost currency")
	# Hidden taking tags the same real source, but cannot create an omniscient report.
	for box in game.current_data.storage:
		if box.id=="storage.town.merchant.sealed":spec=box
	game.player.position=spec.pos+Vector2(0,-30);law.witness_query=func(_a,_p):return []
	row=store.entries(spec.id).filter(func(entry):return entry.definition=="cloth")[0]
	check(game.world_storage.transfer(spec,row.uid,1,"player.pack").accepted,"Unwitnessed domain transfer failed")
	cases=law.pending(merchant);case_id=cases[0].id
	check(not cases[0].reported and not law.has_reported_debt("player"),"Unseen property incident became an omniscient report")
	var own:=store.snapshot_owners(["player",merchant]);var own_cloth:=store.count("player","cloth")
	check(law.return_goods(case_id).accepted and store.count("player","cloth")==own_cloth-1 and store.with_property("property_case",case_id).is_empty(),"Returning accessible actual goods did not resolve case")
	# Failed return has full owner/tag rollback, not a partial transfer.
	row=store.entries(spec.id).filter(func(entry):return entry.definition=="cloth")[0]
	game.world_storage.transfer(spec,row.uid,1,"player.pack");case_id=law.pending(merchant)[0].id
	while store.receive(merchant,"river_maul",1)==1:pass
	while store.receive(merchant,"cloth",99)>0:pass
	own=store.snapshot_owners(["player",merchant])
	check(not law.return_goods(case_id).accepted and store.snapshot_owners(["player",merchant])==own and not law.cases[case_id].settled,"Full legal owner capacity lost tags or half-returned goods")
	store.pay(merchant,{"river_maul":2});check(law.return_goods(case_id).accepted,"Freed owner capacity did not allow original tagged goods")
	# Only a complete remainder can satisfy a return; partial consumption needs compensation.
	store.ensure_container("test.private", "storage:test.private","cache",4);store.receive_into("test.private","cloth",2);law.register_source("test.private",merchant)
	row=store.entries("test.private")[0];check(law.take("player","test.private","player.pack",row.uid,2,game.player.position).accepted,"Partial-remainder fixture failed")
	case_id=law.pending(merchant)[0].id;var lost:=store.with_property("property_case",case_id)[0] as Dictionary
	store.remove_from(store.locate(lost.uid),"cloth",1)
	check(not law.return_goods(case_id).accepted and not law.cases[case_id].settled,"Partial remaining goods erased a larger property obligation")
	store.receive("player","coin",20);check(law.compensate(case_id).accepted,"Incomplete goods could not resolve through funded compensation")
	law.witness_query=game.session.property_witnesses
	game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true)
	check(not game.session.law.has_reported_debt("player") and game.session.law.cases.values().all(func(entry):return entry.settled),"Settled legal records reopened after cold reentry")
	await fixture.close()
	if failures.is_empty():print("PASS property: real witnesses/private source, exact partial UID tags, clean-stock isolation, service/trade denial, validated cold cases, finite compensation, unseen ownership, full-capacity return rollback")
	quit(0 if failures.is_empty() else 1)
