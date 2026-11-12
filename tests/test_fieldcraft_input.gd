extends "res://tests/support/input_scene_probe.gd"
## Controlled travel/weapon setup; actual UI/input, normal AI and original health/resource rules.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const HOUND="river.enemy.camp.fieldcraft.hound.v1"
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
	await at(Vector2(-4250,1600));await tap(KEY_F);await frames(6)
	check(game.region_id=="river_workshop","Actual door failed to enter workshop")
	await at(Vector2(250,230));await tap(KEY_F)
	await click("剥取小刀 ×1");await click("取整组到背包")
	await click("猎人入门：剥皮 ×1");await click("取整组到背包");await tap(KEY_ESCAPE)
	var store:=game.session.inventory;var knife:=store.find_owned("player","field_knife")
	check(not knife.is_empty() and store.entries("storage.town.workshop.fieldcraft").is_empty(),"Real public supply chest did not transfer finite knife/book")
	await tap(KEY_I);await click("猎人入门：剥皮 ×1");await click("更多"); await click("移至口袋");await click("使用一份")
	await capture("01-learning-skinning");await create_timer(2.4).timeout
	check(game.session.fieldcraft.knows("player","skinning") and store.count("player","book_skinning")==0 and not paused,"Real inventory book use failed or paused world")
	await at(Vector2(0,330));await tap(KEY_F);await frames(6)
	store.receive("player","river_spear",1);store.equip("player",store.find_owned("player","river_spear"))
	var hound: Enemy
	for foe in game.active_enemies:
		if foe.actor_context.id==HOUND:hound=foe
	check(hound!=null,"Live authored hound missing")
	if not hound:await fixture.close();quit(1);return
	await at(hound.position+Vector2(-120,0))
	var hp:=game.player.health_component.hp;var mana:=game.player.mana_component.mp
	var started:=Time.get_ticks_msec();var swings:=0
	while is_instance_valid(hound) and not hound.health_component.is_dead and not game.player.health_component.is_dead and Time.get_ticks_msec()-started<16000:
		await aim_world(hound.global_position)
		await pointer_button(MOUSE_BUTTON_LEFT,true);await pointer_button(MOUSE_BUTTON_LEFT,false)
		swings+=1
		if swings==2:await capture("02-live-hound-combat")
		await create_timer(.58).timeout
	var elapsed:=(Time.get_ticks_msec()-started)/1000.0
	var hurt:=hp-game.player.health_component.hp
	print("FIELDCRAFT_LIVE_DUEL seconds=%.2f hp_loss=%d swings=%d mp_before=%d mp_after=%d"%[elapsed,hurt,swings,mana,game.player.mana_component.mp])
	check(game.loot.corpses.has(HOUND) and not game.player.health_component.is_dead,"Normal AI hound fight did not complete with actual weapon input")
	if not game.loot.corpses.has(HOUND):await fixture.close();quit(1);return
	await at(game.loot.corpses[HOUND].position);await tap(KEY_F)
	await click("兽牙");await capture("03-unlearned-fangs-retained")
	await click("兽皮");await click("开始专业处理")
	check(game.player.field_work.panel.visible and not game.player.ui_blocked,"Loot UI did not hand input over to live work")
	await tap(KEY_F);await capture("04-live-professional-work");await create_timer(3.5).timeout
	check(store.count("player","beast_hide")==1 and store.entries(HOUND+".anatomy").size()==1,"Actual F work did not produce hide and retain unlearned fangs")
	await at(Vector2(-3100,1800));await tap(KEY_F)
	store.receive("player","ash",1) # Controlled manufacturing input; hide is from the actual fight/work.
	await click("鞣制兽皮抹布");await capture("05-hide-manufacturing");await click("加工：布料");await tap(KEY_ESCAPE)
	check(store.count("player","beast_hide")==0 and store.count("player","cloth")>=2,"Actual workbench did not transform harvested hide")
	# Actual NPC service path to advanced knowledge; tuition stock is controlled.
	store.receive("player","coin",6)
	var trainer:=game.session.actor_for_id(TrainingCatalog.default_catalog().actor_id)
	await at(trainer.position+Vector2(0,35));await tap(KEY_F);await click("学习武技与野外技艺")
	await click("野外技艺：取牙 · 河谷币 ×6（持有6）")
	check(game.session.fieldcraft.knows("player","fang_work") and store.count("player","coin")==0,"Real NPC course failed to take exact tuition/teach")
	await capture("07-advanced-fieldcraft-course");await tap(KEY_ESCAPE)
	await tap(KEY_F5)
	var cloth:=store.count("player","cloth")
	await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true);live();store=game.session.inventory
	check(game.session.fieldcraft.knows("player","skinning") and store.item(knife)!=null and store.count("player","cloth")==cloth and store.entries(HOUND+".anatomy").size()==1,"F5/cold reentry lost tool/knowledge/part remainder")
	root.size=Vector2i(960,600)
	await at(game.loot.corpses[HOUND].position);await tap(KEY_F);await click("兽牙");await capture("06-reloaded-retained-fangs-small")
	check(not paused,"Reloaded loot panel paused simulation")
	await fixture.close()
	if failures.is_empty():print("PASS fieldcraft input: real public chest/book/pocket use, normal AI hound duel via mouse, F corpse/extraction, locked unlearned parts, actual hide craft/NPC advanced course, F5/cold reentry and small-window loot; controlled travel, spear, ash and tuition")
	quit(0 if failures.is_empty() else 1)
