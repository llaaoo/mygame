extends SceneTree
## Domain/save integration; explicit safe fixture, physics/AI isolated. Not combat balance.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var fixture:=Fixture.new(self);var game:=await fixture.boot(true,true)
	var actor:=game.player;var mana:=actor.mana_component;var magic:=actor.actor_context.magic
	check(not magic.awakened and mana.max_mp==0 and mana.mp==0,"A genuine new frontier did not start without magic")
	check(mana.magic_state==magic,"ActorContext and ManaComponent disagree on qualification ownership")
	actor.stats_component.modify_stat("intelligence",3)
	mana.max_mp=999;mana.mp=999;actor.restore_mp(500,"potion");mana.tick(60)
	for i in range(15):actor._apply_stats()
	check(mana.max_mp==0 and mana.mp==0,"Stats, raw capacity or potion restored unawakened MP")
	var shared:=load("res://content/items/equipment/void_robe.tres") as EquipmentData
	game.session.inventory.register_definition(shared)
	game.session.inventory.receive("player",shared.id,1)
	var robe:=game.session.inventory.find_owned("player",shared.id)
	check(game.session.inventory.equip("player",robe).accepted,"Could not equip actual mana-capacity gear fixture")
	check(mana.max_mp==0 and mana.mp==0,"Equipment bypassed awakening")
	game.session.inventory.unequip("player",shared.slot_type)
	check(game.session.inventory.pay("player",{shared.id:1}),"Could not clean the controlled external gear fixture before saving")
	var hp:=actor.health_component.max_hp;var stamina:=actor.actor_context.actions.stamina.maximum
	check(magic.awaken(actor,"test.integration").accepted,"Qualified actor could not awaken")
	check(actor.health_component.max_hp==hp-10 and actor.actor_context.actions.stamina.maximum==stamina-10,"Sacrifice did not apply once to effective maxima")
	check(mana.max_mp==69 and mana.mp==0,"Mana baseline/intelligence relation or no-refill contract changed")
	check(not magic.awaken(actor,"test.duplicate").accepted,"Repeated awakening was accepted")
	var buffs:=actor.get_node("BuffManager") as BuffManager
	check(roundi(buffs.preview_attribute_delta("max_hp"))==actor.health_component.max_hp,"Awakened growth preview did not match the real permanent HP maximum")
	var next_hp:=roundi(buffs.preview_attribute_delta("max_hp",5.0))
	actor.stats_component.modify_stat("endurance",1)
	check(actor.health_component.max_hp==next_hp,"Endurance HP preview and actual awakening-adjusted capacity disagree")
	actor.stats_component.modify_stat("endurance",-1)
	actor.restore_mp(7,"test.explicit_budget")
	var snapshot:=magic.serialize_save_data()
	game._save_progress();await fixture.close()
	fixture=Fixture.new(self);game=await fixture.boot(true,true);actor=game.player;mana=actor.mana_component
	check(actor.actor_context.magic.serialize_save_data()==snapshot,"Actual save/re-entry changed awakening/cost identity")
	check(mana.mp==7 and mana.max_mp==69 and actor.health_component.max_hp==hp-10 and actor.actor_context.actions.stamina.maximum==stamina-10,"Restore refilled or charged permanent costs again")
	var saved:=game.session.snapshot();var invalid:=saved.duplicate(true);invalid.actors.player.magic={}
	check(not CampaignSession.valid_snapshot(invalid),"Explicit empty magic was treated as a legacy record")
	var future:=saved.duplicate(true);future.actors.player.magic.schema=2
	check(game.session.snapshot_read_status(future)==SaveSections.Status.UNSUPPORTED,"Future magic schema was accepted as writable")
	await fixture.close()
	# A real checked-in pre-awakening save, with only the test's zero-MP budget
	# applied to its existing records; no current payload is relabelled as old.
	var repository:=SaveRepository.new()
	var historic:="res://docs/reviews/senior-first-play-2026-11-08/evidence/final-normal-save_3.sav"
	var old:=repository.read(historic)
	check(old.usable(),"Historical game save could not be read")
	if old.usable():
		var section: Dictionary=old.data.extensions.grayriver_frontier
		check(not section.has("magic_schema") and not section.foundation.actors.player.has("magic"),"Historical fixture is no longer genuinely pre-awakening")
		section.foundation.actors.player.mp=0;section.survival_state["mp"]=0
		var file:=FileAccess.open("user://save_3.sav",FileAccess.WRITE);file.store_var(old.data);file.close()
		DirAccess.remove_absolute("user://save_3.sav.bak")
		fixture=Fixture.new(self);game=await fixture.boot(true,true);actor=game.player
		check(actor.actor_context.magic.awakened and actor.actor_context.magic.legacy_exempt,"Real old zero-MP record lost its casting qualification")
		check(actor.actor_context.magic.hp_cost==0 and is_zero_approx(actor.actor_context.magic.stamina_cost) and actor.mana_component.mp==0,"Old zero-MP traveler was refilled or charged new awakening costs")
		await fixture.close()
	if failures.is_empty():print("PASS magic awakening: genuine new gate, stat/potion/gear boundaries, once-only permanent maxima, actual save/re-entry, strict explicit state/future schema and real historical zero-MP compatibility")
	quit(0 if failures.is_empty() else 1)
