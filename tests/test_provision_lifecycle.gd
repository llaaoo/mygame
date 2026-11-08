extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func eat(game: GrayriverGame,id: String) -> void:
	game.session.inventory.receive("player",id,1)
	game.survival.begin_eating(id)
	check(game.player.field_work.is_busy(),"Food failed ordinary preparation: "+id)
	game.player.field_work.tick(2)
	game.player.field_work.close_panel()
func run() -> void:
	var fixture:=Fixture.new(self); var game:=await fixture.boot(true)
	var actor:=game.player; var buffs:=actor.get_node("BuffManager") as BuffManager
	var needs:=game.survival.needs
	eat(game,"ration"); eat(game,"clean_water"); eat(game,"tea")
	check(needs.meal=="ration" and buffs.has_buff("meal_fortitude") and needs.recovery().mana_bonus==1.5,"Ordinary food consumption failed unified effects")
	var before:=needs.meal_remaining
	needs.tick(10,12)
	check(needs.meal_remaining==before,"Needs advanced the Buff clock a second time")
	buffs.tick(10)
	check(is_equal_approx(needs.meal_remaining,before-10) and is_equal_approx(needs.water_remaining,110),"Buff expiry and provision UI disagree")
	eat(game,"broth")
	check(needs.meal=="broth" and not buffs.has_buff("meal_fortitude") and actor.stats_component.effective_stat("endurance")==13,"Meal replacement kept duplicate attribute effects")
	buffs.remove_status("broth_fortitude")
	check(needs.meal.is_empty() and needs.meal_remaining==0 and needs.recovery().health_bonus==0,"Dispelled meal retained recovery")
	eat(game,"ration")
	buffs.apply_buff(load("res://content/spell_operations/statuses/toxin.tres"),game.active_enemies[0])
	actor.skill_manager.combinations.cooldowns["ignite"]=8.0
	CombatExecutor.report_hit(game.active_enemies[0],actor,10000,actor.position,null,["physical"])
	check(actor.health_component.is_dead and needs.meal_remaining==0 and needs.water_remaining==0 and needs.tea_remaining==0 and not buffs.has_buff("poison") and actor.health_component.max_hp==100,"Death retained provision/status contributions")
	check(game.session.actor_records.player.dead and game.session.actor_records.player.hp==0 and game.session.actor_records.player.effects.entries.is_empty(),"Death save retained a previous live effect snapshot")
	check(SaveRepository.new().read("user://save_3.sav").usable(),"Death state was not saveable")
	await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	check(not game.player.health_component.is_dead and game.player.health_component.hp<=51 and game.player.health_component.max_hp==100 and game.survival.needs.meal_remaining==0,"Reloading death resurrected old food or bypassed half-health recovery")
	check(game.player.skill_manager.combinations.cooldowns.get("ignite",0)>7,"Death recovery erased action cooldown")
	# A real v8 envelope with the historical mismatched food state migrates once.
	game._save_progress(); var section: String=game.save_section; await fixture.close()
	var data:=SaveRepository.new().read("user://save_3.sav").data
	data.version=8
	var record: Dictionary=data.extensions[section].foundation.actors.player
	record.erase("provision_schema")
	record.needs.meal=""; record.needs.meal_remaining=0.0; record.needs.water_remaining=45.0; record.needs.tea_remaining=30.0
	record.effects.entries.append({"path":"res://content/status/meal_fortitude.tres","id":"meal_fortitude","duration":180.0,"remaining":150.0,"stacks":1,"elapsed":0.0,"source_magic":0.0,"source_id":"player"})
	record.effects.entries.append({"path":"res://content/spell_operations/statuses/toxin.tres","id":"poison","duration":5.0,"remaining":4.0,"stacks":1,"elapsed":0.0,"source_magic":0.0,"source_id":"player"})
	var file:=FileAccess.open("user://save_3.sav",FileAccess.WRITE); file.store_var(data); file.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	needs=game.survival.needs; buffs=game.player.get_node("BuffManager") as BuffManager
	check(not buffs.has_buff("meal_fortitude") and needs.meal_remaining==0 and needs.water_remaining>44 and needs.water_remaining<=45,"V8 migration retained phantom food or refilled legacy water")
	check(buffs.has_buff("poison") and needs.tea_remaining<=30 and needs.tea_remaining>29,"Legacy tea replayed cleanse on load")
	game._save_progress(); await fixture.close()
	fixture=Fixture.new(self); game=await fixture.boot(true)
	check(game.survival.needs.water_remaining<=45 and game.player.health_component.max_hp==100,"Migrated effects were renewed on second load")
	await fixture.close()
	if failures.is_empty(): print("PASS provision lifecycle: real consumption/replacement/dispel, single clock, death before recovery/save, retained cooldown and v8 migration/reentry")
	quit(0 if failures.is_empty() else 1)
