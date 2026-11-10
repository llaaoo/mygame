extends "res://tests/support/input_scene_probe.gd"
## Authored sources and normal AI; travel/spear/return provisions are controlled fixtures.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const HOUND="river.enemy.camp.depth.ridge_hound.3.v1"
func at(point: Vector2) -> void:
	game.player.position=point;game.player.get_node("Camera2D").reset_smoothing();await frames(6)
func tap(code: Key) -> void:
	await key(code,true);await key(code,false)
func live() -> void:
	GameRuntime.instance.set_process(true)
	for foe in game.active_enemies:foe.process_mode=Node.PROCESS_MODE_INHERIT
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self);game=await fixture.boot(true);live()
	await at(Vector2(-4250,1600));await tap(KEY_F)
	check(game.region_id=="river_workshop","Real F door failed")
	await at(Vector2(250,230));await tap(KEY_F)
	await click("剥取小刀 ×1");await click("取整组到背包")
	await click("猎人入门：剥皮 ×1");await click("取整组到背包");await tap(KEY_ESCAPE)
	await tap(KEY_I);await click("猎人入门：剥皮 ×1");await click("移至口袋");await click("使用一份");await create_timer(2.4).timeout
	check(game.session.fieldcraft.knows("player","skinning"),"Real finite book did not teach actual hunting knowledge")
	await at(Vector2(0,330));await tap(KEY_F)
	await at(Vector2(-3500,2550));await tap(KEY_F)
	check(game.progress.claims.has("river.hunting.route"),"Actual hunting-route note failed to introduce evidence quest")
	if is_instance_valid(game.ui.modal):await tap(KEY_ESCAPE)
	await tap(KEY_J);await click("委托记录");await click("巡林取证：知识与威胁");await click("追踪这个委托")
	check(game.progress.tracked_quest=="river.hunting_evidence" and not game.guidance.tracked().title.contains("报告"),"Actual J tracking promised a report before earned practice")
	await capture("00-unfinished-evidence-guidance");await tap(KEY_ESCAPE)
	var store:=game.session.inventory;store.receive("player","river_spear",1);store.equip("player",store.find_owned("player","river_spear"))
	var hound:=game.session.actor_for_id(HOUND) as Enemy
	check(hound!=null,"Territorial hound absent")
	if not hound:await fixture.close();quit(1);return
	await at(hound.position+Vector2(-205,0));await create_timer(.35).timeout
	check(hound.actor_context.awareness.phase=="warning" and hound._get_current_target()==null,"Native territory warned too late or immediately attacked")
	await capture("01-territory-warning")
	await key(KEY_A,true);await create_timer(.55).timeout;await key(KEY_A,false)
	check(hound.actor_context.awareness.phase=="quiet","Actual withdrawal did not avoid combat")
	await at(hound.position+Vector2(-120,0))
	var hp:=game.player.health_component.hp;var started:=Time.get_ticks_msec();var swings:=0;var mp:=game.player.mana_component.mp
	while is_instance_valid(hound) and not hound.health_component.is_dead and not game.player.health_component.is_dead and Time.get_ticks_msec()-started<16000:
		await aim_world(hound.global_position);await pointer_button(MOUSE_BUTTON_LEFT,true);await pointer_button(MOUSE_BUTTON_LEFT,false);swings+=1
		if swings==2:await capture("02-territory-combat")
		await create_timer(.58).timeout
	print("WORLD_DEPTH_LIVE seconds=%.2f hp_loss=%d swings=%d mp=%d->%d normal_ai=true"%[(Time.get_ticks_msec()-started)/1000.0,hp-game.player.health_component.hp,swings,mp,game.player.mana_component.mp])
	check(game.loot.corpses.has(HOUND) and not game.player.health_component.is_dead,"Normal AI territory duel failed actual mouse combat")
	if not game.loot.corpses.has(HOUND):await fixture.close();quit(1);return
	await at(game.loot.corpses[HOUND].position);await tap(KEY_F);await click("兽皮");await click("开始专业处理");await tap(KEY_F);await create_timer(3.5).timeout
	check(game.session.fieldcraft.harvest_count("player","skinning")==1 and store.count("player","beast_hide")==1,"Real corpse work failed persistent professional practice")
	# The same output becomes a paid finite NPC delivery, then earned identity.
	var merchant:=game.session.actor_for_id(TownServices.MERCHANT)
	await at(merchant.position+Vector2(-35,0));await tap(KEY_F);await click("差事：完整兽皮供给");await click("接受委托")
	var money:=store.count("player","coin");await click("交付物资并领取报酬")
	check(store.count("player","coin")==money+6 and game.session.conversations.favor_state(TownServices.MERCHANT,"hides")=="waiting","Actual repeat-contract UI failed funded first delivery/deadline")
	await capture("03-funded-supply-next-batch");await tap(KEY_ESCAPE)
	var trainer:=game.session.actor_for_id(TrainingCatalog.default_catalog().actor_id)
	await at(trainer.position+Vector2(0,35));await tap(KEY_F);await click("身份与专长誓约");await click("灰河猎队 · 查看誓约");await click("确认加入灰河猎队")
	check(game.session.relations.affiliation("player")=="hunters" and game.player.actor_context.martial.learned.has("hunter_pin"),"Actual charter confirmation failed identity/art")
	await capture("04-earned-charter");await tap(KEY_ESCAPE)
	await at(Vector2(-4250,1600));await tap(KEY_F);await at(Vector2(-100,55));await tap(KEY_F)
	check(game.ui.modal!=null and not paused,"Member box inaccessible or paused world")
	await capture("05-finite-member-box");await tap(KEY_ESCAPE);await at(Vector2(0,330));await tap(KEY_F)
	# Original private source, witnessed taking and actual return through an NPC.
	await at(Vector2(-3150,2280));await tap(KEY_F);await click("金属碎料 ×2");await click("擅自取1件到背包");await tap(KEY_ESCAPE)
	check(game.session.law.has_reported_debt("player"),"Visible private-stock interaction had no actual witness consequence")
	merchant=game.session.actor_for_id(TownServices.MERCHANT)
	await at(merchant.position+Vector2(-35,0));await tap(KEY_F);await click("处理私产纠纷与遗产委托")
	var name:=game.session.conversations.catalog.profile(TownServices.MERCHANT).character.title
	var case_id: String=game.session.law.pending(TownServices.MERCHANT)[0].id
	await capture("06-private-property-mediation");await click("归还："+name+" · "+case_id)
	check(not game.session.law.has_reported_debt("player"),"Actual return UI failed property reconciliation")
	await tap(KEY_ESCAPE)
	store.receive("player","ration",2);store.receive("player","clean_water",2)
	await at(Vector2(-2800,-1800));await tap(KEY_ESCAPE);await click("现场撤回河谷镇")
	check(game.player.field_work.panel.visible and not game.player.field_work.is_busy(),"Return menu skipped choice")
	var hours: float=game.retreat._quote.hours;var portions: int=game.retreat._quote.portions;var time:=store.clock_seconds;var rations:=store.count("player","ration")
	await capture("07-actual-journey-cost");await tap(KEY_F);await create_timer(3.7).timeout
	check(game.is_at_base() and store.clock_seconds>=time+hours*60 and store.count("player","ration")==rations-portions,"Actual F return failed time/cost integration")
	print("WORLD_DEPTH_RETURN hours=%.1f portions=%d elapsed_simulation=%.2f"%[hours,portions,store.clock_seconds-time])
	await tap(KEY_F5);var coins:=store.count("player","coin")
	await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true);live();store=game.session.inventory
	check(game.session.relations.affiliation("player")=="hunters" and game.session.fieldcraft.harvest_count("player","skinning")==1 and store.count("player","coin")==coins and game.session.law.cases[case_id].settled,"Cold reentry lost earned identity/practice/currency/legal receipt")
	root.size=Vector2i(960,600);await at(Vector2(-4250,1600));await tap(KEY_F);await at(Vector2(-100,55));await tap(KEY_F);await capture("08-reloaded-member-box-small")
	check(not paused,"Small-window member UI paused world")
	await fixture.close()
	if failures.is_empty():print("PASS world depth input: real public book, territory warning/withdrawal, normal AI mouse duel, professional work -> finite NPC supply -> charter/member access, witnessed property/return, prepared journey/F5/cold save/small UI; controlled travel, spear and provisions")
	quit(0 if failures.is_empty() else 1)
