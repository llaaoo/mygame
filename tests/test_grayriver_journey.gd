extends SceneTree
const Legacy:=preload("res://tests/support/mvp_fixture.gd")
const Fixture:=preload("res://tests/support/grayriver_fixture.gd")
var errors:Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:errors.append(message);push_error(message)
func map_key() -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=KEY_M;event.physical_keycode=KEY_M;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
func run() -> void:
	var legacy:=Legacy.new(self)
	var old:=await legacy.boot(true)
	old.player.health_component.hp=51
	old.player.mana_component.mp=27
	old._save_progress()
	var prototype:=FileAccess.get_file_as_bytes("user://save_2.sav")
	await legacy.close()
	var fixture:=Fixture.new(self)
	var game:=await fixture.boot(true,true)
	var p:=game.player
	p.position=Vector2(-1800,1000)
	p.health_component.hp=67
	p.mana_component.mp=29
	game._save_progress()
	var saved:=SaveManager.instance.read_extension(3,"grayriver_frontier")
	check(saved.journey.position==[-1800.0,1000.0] and saved.survival_state.hp==67,"Saved journey lost exact position or vitals")
	check(prototype==FileAccess.get_file_as_bytes("user://save_2.sav"),"Frontier overwrote prototype slot")
	# One defeated outdoor actor survives leaving, loading and encountering the same area again.
	var enemy:Enemy=game.active_enemies[0]
	var id:String=enemy.get_meta("frontier_claim")
	enemy.rewards_enabled=false
	enemy.take_damage(1000)
	game._save_progress()
	await fixture.close()
	game=await fixture.boot(true,true)
	check(game.player.position.distance_to(Vector2(-1800,1000))<2 and game.player.health_component.hp==67 and game.player.mana_component.mp==29,"Bootstrap teleported or refilled saved traveler")
	check(game.active_enemies.size()==game.current_data.encounters.size()-1 and game.progress.claims.has(id),"Defeated outdoor actor respawned on load")
	await map_key()
	check(not paused and game.player.ui_blocked,"Map failed pause lifecycle")
	await map_key()
	check(not paused and not is_instance_valid(game.ui.modal),"M cannot close live map")
	game.player.position=Vector2(-3300,2100)
	check(game.is_at_base(),"Town service boundary broken")
	game.progress.claims["river.bridge_fixed"]=true
	game.replay_encounters()
	for i in range(8):await process_frame
	check(game.progress.claims.has("river.bridge_fixed") and game.active_enemies.size()==game.current_data.encounters.size() and game.active_enemies.all(func(e):return not e.rewards_enabled),"Rehearsal lost permanent world or restored rewards")
	var inventory:=game.player.skill_manager.combinations.supplies.serialize()
	game.player.position=Vector2(2000,1000)
	game.player.take_damage(1000)
	for i in range(3):await process_frame
	check(game.player.health_component.is_dead and game.progress.claims.has("river.bridge_fixed"),"Death erased permanent construction")
	var defeat_time:=game.session.inventory.clock_seconds
	await fixture.close()
	game=await fixture.boot(true,true)
	check(game.session.inventory.clock_seconds>=defeat_time+120 and not game.session.expedition.pending_rescue,"Cold defeat resume skipped the outstanding two-hour journey")
	check(game.is_at_base() and not game.player.health_component.is_dead and game.player.health_component.hp==50 and game.player.mana_component.mp==30,"Dead saved traveler did not recover half vitals in town")
	check(game.player.skill_manager.combinations.supplies.serialize()==inventory and game.progress.claims.has("river.bridge_fixed"),"Death resume refilled materials or lost world facts")
	await fixture.close()
	old=await legacy.boot(true)
	check(old.player.health_component.hp==51 and old.player.mana_component.mp==27,"Prototype cannot continue original save")
	await legacy.close()
	if errors.is_empty():print("Grayriver journey passed: isolated slots, exact resume/vitals, stable enemy facts, map pause, reward-free replay, death resume and legacy continuation")
	quit(0 if errors.is_empty() else 1)
