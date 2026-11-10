extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func settle() -> void:
	for i in 8:await process_frame
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot(true,true)
	game.session.set_process(false)
	var store:=game.session.inventory;var player:=game.player
	player.position=Vector2(-2800,-1800)
	store.receive("player","ration",3);store.receive("player","clean_water",3)
	player.health_component.hp=50;player.mana_component.mp=20
	var time:=store.clock_seconds;var ration:=store.count("player","ration");var water:=store.count("player","clean_water")
	game.retreat.begin();var work:=player.field_work
	check(work.panel.visible and not work.is_busy() and work.methods.size()==2,"Return skipped meaningful preparation/slow choice")
	player.position+=Vector2(20,0)
	check(not work.reason_for(work.methods[0]).is_empty() and not work.start_selected(),"Stale departure quote remained usable after moving")
	work.close_panel();game.retreat.begin()
	check(work.start_selected(),"Safe prepared return refused")
	work.tick(1);player.position+=Vector2(20,0);work.tick(.1)
	check(not work.is_busy() and store.count("player","ration")==ration and store.clock_seconds==time,"Interrupted return charged time/materials")
	work.close_panel();game.retreat.begin();var hours: float=game.retreat._quote.hours;var portions: int=game.retreat._quote.portions
	check(work.start_selected(),"Prepared return failed to restart");work.tick(10);await settle()
	check(game.region_id=="camp" and game.is_at_base() and is_equal_approx(store.clock_seconds-time,hours*game.session.production.seconds_per_hour),"Prepared return failed actual world-time/travel integration")
	check(player.health_component.hp==50 and player.mana_component.mp==20,"Journey granted flat rest healing or mana")
	check(store.count("player","ration")==ration-portions and store.count("player","clean_water")==water-portions,"Prepared return charged incorrect actual portions")
	# A lack of provisions still allows a slower, more exhausting route.
	player.position=Vector2(-2800,-1800);store.pay("player",{"ration":store.count("player","ration"),"clean_water":store.count("player","clean_water")})
	time=store.clock_seconds;game.retreat.begin();hours=game.retreat._quote.hours;work=player.field_work
	check(not work.reason_for(work.methods[0]).is_empty() and work.reason_for(work.methods[1]).is_empty(),"No-resource fallback unavailable or prepared journey was free")
	work.selected=1;check(work.start_selected(),"Slow fallback refused");work.tick(10);await settle()
	check(is_equal_approx(store.clock_seconds-time,hours*2*game.session.production.seconds_per_hour),"Slow fallback did not cost double game time")
	# Defeat retains exact pack contents at the real site; rescue cannot be replayed.
	player.position=Vector2(-2800,-1800);store.receive_into("player.pack","river_spear",1)
	var rows:=store.entries("player.pack");var uid: String=rows.filter(func(row):return row.definition=="river_spear")[0].uid
	player.take_damage(10000);await settle()
	check(player.health_component.is_dead and not store.is_attached("player.pack") and store.item(uid)!=null and store.dropped_pack_region("player.pack")=="camp","Defeat deleted or retained equipped pack instead of actual recoverable contents")
	time=store.clock_seconds;check(game.retreat.rescue(),"Dead-player rescue refused");check(not game.retreat.rescue(),"Rescue time/callback replayed");await settle()
	check(game.is_at_base() and is_equal_approx(store.clock_seconds-time,game.rules.expedition.rescue_hours*game.session.production.seconds_per_hour) and store.item(uid)!=null,"Rescue did not preserve recoverable loss and actual hours")
	game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true);store=game.session.inventory
	check(not store.is_attached("player.pack") and store.item(uid)!=null,"Cold save refilled/re-attached lost pack")
	game.player.position=store.dropped_pack_position("player.pack")
	check(game.session.recover_pack("player","player.pack") and store.is_attached("player.pack") and store.item(uid)!=null,"Real-site pack recovery lost UID or refused original contents")
	# Quitting at the death screen cannot skip the same outstanding rescue cost.
	game.player.position=Vector2(-2800,-1800);game.player.health_component.invincible=false;game.player.take_damage(10000);await settle()
	check(game.session.expedition.pending_rescue,"Defeat rescue was not persistently outstanding")
	time=store.clock_seconds;game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true);game.session.set_process(false);store=game.session.inventory
	check(not game.session.expedition.pending_rescue and store.clock_seconds>=time+game.rules.expedition.rescue_hours*60 and not game.player.health_component.is_dead,"Cold death reload skipped actual outstanding rescue")
	var rescued_time:=store.clock_seconds;game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true)
	check(game.session.inventory.clock_seconds<rescued_time+10,"Cold reentry double-charged completed rescue")
	await fixture.travel("river_workshop");game.player.position=Vector2.ZERO;game._save_progress();await fixture.close();fixture=Fixture.new(self);game=await fixture.boot(true,true)
	check(game.region_id=="river_workshop" and game.retreat.distance_query.is_valid(),"Interior cold start missed expedition distance injection")
	await fixture.close()
	if failures.is_empty():print("PASS expedition: meaningful return choice, interruption no charge, exact game hours and food/water, slow resource-free fallback, recoverable defeat pack/UID/cold save, once-only rescue and interior distance injection")
	quit(0 if failures.is_empty() else 1)
