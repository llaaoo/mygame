extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot(true,true)
	var store:=game.session.inventory;var domain:=game.session.conversations;var merchant:=TownServices.MERCHANT
	var npc:=game.session.actor_for_id(merchant) as ServiceNPC;npc.set_physics_process(false);npc.actor_context.actions.set_physics_process(false)
	game.player.position=npc.position+Vector2(-35,0)
	var handle:=domain.begin(merchant)
	check(handle.accepted and not domain.choose(handle.token,"hides","accept").accepted,"Professional supply accepted unlearned knowledge")
	game.session.fieldcraft.learn("player","skinning");store.receive("player","beast_hide",4)
	check(domain.choose(handle.token,"hides","accept").accepted,"Known professional contract refused")
	var coins:=store.count("player","coin");var purse:=store.count(merchant,"coin");var stock:=store.count(merchant,"beast_hide")
	check(domain.choose(handle.token,"hides","deliver").accepted and domain.favor_state(merchant,"hides")=="waiting","First bounded repeat contract failed")
	var before:=store.snapshot();check(not domain.choose(handle.token,"hides","deliver").accepted and store.snapshot()==before,"Same-hour repeat contract minted money")
	var due: float=domain.snapshot().cycles[merchant+"/hides"].ready_at
	game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true);store=game.session.inventory;domain=game.session.conversations
	check(domain.favor_state(merchant,"hides")=="waiting" and domain.snapshot().cycles[merchant+"/hides"].ready_at==due,"Reload renewed or removed repeat-contract deadline")
	npc=game.session.actor_for_id(merchant) as ServiceNPC;npc.set_physics_process(false);npc.actor_context.actions.set_physics_process(false);npc.hour_query=func():return 10.0
	game.player.position=npc.position+Vector2(-35,0);handle=domain.begin(merchant)
	for delivery in [2,3]:
		store.clock_seconds=domain.snapshot().cycles[merchant+"/hides"].ready_at
		check(domain.choose(handle.token,"hides","deliver").accepted,"Due real delivery refused batch %d"%delivery)
	check(domain.favor_state(merchant,"hides")=="completed" and store.count("player","coin")==coins+18 and store.count(merchant,"coin")==purse-18 and store.count(merchant,"beast_hide")==stock+3,"Three-batch contract failed finite stock/currency conservation")
	before=store.snapshot();check(not domain.choose(handle.token,"hides","deliver").accepted and store.snapshot()==before,"Contract exceeded authored quota")
	# Actual stock shortage, rather than a replenishing abstract demand counter.
	var hide_uid:=store.find_owned("player","beast_hide")
	var base: int=game.town_services._base_price(hide_uid,false)
	check(game.town_services.total_price(hide_uid,false,1)==base,"Fulfilled stock still offered scarcity premium")
	store.pay(merchant,{"beast_hide":store.count(merchant,"beast_hide")});store.receive("player","beast_hide",3)
	check(game.town_services.total_price(hide_uid,false,3)==base*3+2 and game.town_services.total_price(hide_uid,true,3)>base*3+2,"Scarcity bulk pricing overpaid quota or enabled immediate buyback arbitrage")
	# Real inventory production transforms hunting inputs only when due.
	store.receive(merchant,"beast_hide",1);store.receive(merchant,"ash",1)
	var production:=game.session.production;var definition:=production.catalog.definition("town.hide_bindings")
	check(definition!=null and production.start(definition.id).accepted,"Hunting stock not connected to authored producer")
	var cloth:=store.count(merchant,"cloth");store.clock_seconds+=definition.work_hours*production.seconds_per_hour;production.advance()
	check(store.count(merchant,"cloth")==cloth+2 and store.count(merchant,"beast_hide")==0,"Due producer failed exact hunting stock transformation")
	# First refit fixes a real UID's specialization and leaves the shared Resource intact.
	store.receive("player","river_sabre",1);var uid:=store.find_owned("player","river_sabre")
	store.receive("player","coin",30);store.receive("player","metal_scrap",10);store.receive("player","beast_fang",2)
	var shared:=store.definitions.river_sabre as EquipmentData;var modifiers:=shared.combat_modifiers.duplicate(true)
	check(store.upgrade_instance("player",uid,"control").accepted and store.item(uid).properties.upgrade_path=="control","Control specialization did not attach to actual weapon")
	check(float(store.equipment_definition(uid).combat_modifiers.get("impact_bonus",0))==float(modifiers.get("impact_bonus",0))+6 and shared.combat_modifiers==modifiers,"Refit did not project impact or mutated shared definition")
	before=store.snapshot();check(not store.upgrade_instance("player",uid,"balanced").accepted and store.snapshot()==before,"Upgraded weapon silently changed specialization")
	check(store.equip("player",uid).accepted,"Refitted weapon could not equip")
	check(game.player.actor_context.actions.equipment_value("impact_bonus")>=6 and game.player.actor_context.actions.equipment_value("weapon_stamina_cost")>0,"Refit omitted actual shared combat consumers")
	var actions:=game.player.actor_context.actions;actions.cancel();actions.stamina.current=100
	var strike:=actions.next_attack_profile();var expected_cost:=actions.attack_stamina_cost(strike)
	var attack:=Action.melee(game.player);attack.direction=Vector2.RIGHT
	check(actions.try_action(attack).accepted and is_equal_approx(actions.profile.impact,strike.impact+6) and is_equal_approx(100-actions.stamina.current,expected_cost),"Refit impact/fee failed actual physical action execution")
	actions.cancel()
	store.receive("player","river_coat",2);store.receive("player","beast_hide",1);store.receive("player","cloth",1)
	var coats:=store.entries("player.pack").filter(func(row):return row.definition=="river_coat")
	check(coats.size()>=2,"Armor tradeoff fixtures missing")
	if coats.size()>=2:
		var original:=store.definitions.river_coat as EquipmentData
		check(store.upgrade_instance("player",coats[0].uid,"brace").accepted and store.upgrade_instance("player",coats[1].uid,"mobile").accepted,"Compatible armor specializations refused")
		var brace:=store.equipment_definition(coats[0].uid);var mobile:=store.equipment_definition(coats[1].uid)
		check(is_equal_approx(float(brace.stat_modifiers.move_speed),float(original.stat_modifiers.get("move_speed",0))-3) and float(brace.combat_modifiers.impact_resistance)>.04,"Brace lacked real speed/impact-resistance tradeoff")
		check(is_equal_approx(float(mobile.stat_modifiers.max_hp),float(original.stat_modifiers.get("max_hp",0))-2) and float(mobile.combat_modifiers.dodge_cost)<0,"Mobile armor lacked actual health/dodge tradeoff")
	# Already-accepted favor survives provider death through a named live delegate, using estate money.
	game.session.fieldcraft.learn("player","gland_work")
	store.receive("player","gland_sample",1);game.player.position=npc.position+Vector2(-35,0);handle=domain.begin(merchant)
	check(domain.choose(handle.token,"glands","accept").accepted,"Qualified estate contract fixture refused")
	npc.take_damage(10000);await process_frame
	var aida:=game.session.actor_for_id("river.aida") as ServiceNPC;aida.set_physics_process(false);aida.actor_context.actions.set_physics_process(false);aida.hour_query=func():return 10.0
	game.player.position=aida.position+Vector2(0,35);purse=store.count(merchant,"coin");coins=store.count("player","coin")
	check(domain.deliver_estate(merchant,"glands","river.aida").accepted and store.count(merchant,"coin")==purse-8 and store.count("player","coin")==coins+8,"Named successor fabricated money or blocked actual estate delivery")
	check(not domain.deliver_estate(merchant,"glands","river.aida").accepted,"Estate delivery replayed")
	game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true)
	check(game.session.inventory.item(uid).properties.upgrade_path=="control" and game.session.actor_for_id(merchant)==null,"Cold reentry lost refit or resurrected provider")
	await fixture.close()
	if failures.is_empty():print("PASS economy: knowledge-gated repeat quota/deadline/reentry, stock scarcity bulk pricing, real production, UID specialization/tradeoff/shared combat consumers, named dead-provider estate with finite purse")
	quit(0 if failures.is_empty() else 1)
