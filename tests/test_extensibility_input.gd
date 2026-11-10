extends "res://tests/support/input_scene_probe.gd"
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func run() -> void:
	root.size=Vector2i(1152,648)
	var fixture:=Fixture.new(self); game=await fixture.boot(true)
	GameRuntime.instance.set_process(true)
	for enemy in game.active_enemies: enemy.process_mode=Node.PROCESS_MODE_INHERIT
	var actor:=game.player; var store:=game.session.inventory
	store.receive("player","coin",60); store.receive("player","ration",2); store.receive("player","clean_water",2)
	actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
	await key(KEY_F,true); await key(KEY_F,false)
	await click("店内排产")
	var real_stock_shown:=false
	for label in root.find_children("*","Label",true,false):
		if label.is_visible_in_tree() and label.text.contains("炭屑 ×1（店存6）"): real_stock_shown=true
	check(real_stock_shown,"Production material display read player stock instead of merchant stock")
	await click("安排一批 · 木杆箭")
	check(game.session.production.status("town.arrows").scheduled and not paused,"Real production menu did not schedule live work")
	await capture("production-queued")
	var arrows:=store.count(TownServices.MERCHANT,"arrow")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	actor.position=Vector2(-3500,2130); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
	await key(KEY_F,true); await key(KEY_F,false)
	await point_click(actor.field_work.panel.start_button.get_global_rect().get_center())
	check(actor.field_work.is_busy(),"Actual rest button failed to prepare")
	await create_timer(3).timeout
	check(not game.session.production.status("town.arrows").scheduled and store.count(TownServices.MERCHANT,"arrow")==arrows+6,"One-hour real rest did not finish actual merchant recipe")
	# Buy the produced real stock using the same ordinary shop transaction.
	actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
	await key(KEY_F,true); await key(KEY_F,false); await click("购买实物")
	await click("炭芯法杖 ×1 · 16币"); await click("购买一件 · 16币")
	check(store.find_owned("player","river_staff")!="","Actual merchant stock purchase failed")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	var trainer:=game.session.actor_for_id("river.enemy.service.trainer")
	actor.position=trainer.position+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
	await key(KEY_F,true); await key(KEY_F,false)
	await click("学习武技")
	await capture("course-requirement")
	await click("压阵横扫 · 8币")
	check(actor.actor_context.martial.learned.has("staff_sweep"),"Actual conditional course did not teach owned-weapon requirement")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	root.size=Vector2i(960,600)
	actor.position=TownServices.POINT+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(10)
	await key(KEY_F,true); await key(KEY_F,false); await click("店内排产")
	await click("安排一批 · 火石"); await capture("production-small")
	var retained: Button
	for button in root.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and button.text=="停止排产": retained=button; break
	store.clock_seconds+=60 # Controlled boundary: the open UI observes world work.
	await create_timer(2.1).timeout
	check(is_instance_valid(retained) and retained.text=="安排一批 · 火石","Live order completion replaced controls or left stale cancellation")
	await click("安排一批 · 火石")
	await click("停止排产")
	check(game.session.production.snapshot().jobs.is_empty() and not paused,"Small-window order cancellation failed or paused world")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	game._save_progress(); var before:=game.session.inventory.snapshot(); var knowledge:=actor.actor_context.martial.snapshot()
	await fixture.close(); fixture=Fixture.new(self); game=await fixture.boot(true)
	check(game.session.inventory.snapshot()==before and game.player.actor_context.martial.snapshot()==knowledge and game.session.production.snapshot().jobs.is_empty(),"Real service flow lost stock/knowledge or revived cancelled order on reload")
	await fixture.close()
	if failures.is_empty(): print("PASS extensibility input: real F/shop/production/rest/conditional course, small-window cancel, live world and save/reentry")
	quit(0 if failures.is_empty() else 1)
