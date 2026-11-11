extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
class RejectingExecutor extends SkillExecutor:
	func execute(_skill: SkillData,_context: CastContext) -> bool: return false
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(n:=5) -> void:
	for i in range(n): await physics_frame
func run() -> void:
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot()
	check(Awake.awaken(game.player),"Magic-specific fixture could not establish explicit awakened eligibility")
	var actor:=game.player
	var sm:=actor.skill_manager
	var controller:=sm.combinations
	var supplies:=controller.supplies
	var store:=game.session.inventory
	actor.position=Vector2(-3500,2000)
	actor.mana_component.max_mp=500; actor.mana_component.mp=500
	for id in ["fire_sigil","frost_sigil","storm_sigil","pulse","water_call"]: sm.known_actions[id]=true
	check(sm.material_operations,"Current campaign did not enable material operations")
	check(not sm.knows_action(sm.pool.get_skill("fire_sigil")),"UI still exposes each elemental rune as a separate action")
	sm.equip_slot(0,sm.pool.get_skill("fire_sigil"))
	var rune:=sm.get_slot(0).data
	check(rune.get_id()=="inscribe","Old loadout did not migrate to one inscription action")
	var saved:=sm.serialize_skill_state()
	sm.unequip_slot(0); sm.restore_skill_state(saved)
	check(sm.get_slot(0).data.get_id()=="inscribe","New operation loadout could not restore")
	var legacy_loadout: Dictionary={"slot_0":{"skill_id":"fire_sigil"},"slot_1":{"skill_id":"frost_sigil"},"slot_2":{"skill_id":"storm_sigil"}}
	sm.restore_skill_state(legacy_loadout)
	check(sm.get_slot(0) and not sm.get_slot(1) and not sm.get_slot(2),"Legacy elemental slots were restored as duplicate primitive actions")
	controller.reset_session()
	var free:=controller.preview(rune,actor)
	check(free.ready and free.material_costs.is_empty() and free.skill.field_type=="arcane","Material-free inscription has no explicit valid payload")
	check(sm.use_slot(0,actor,Vector2.RIGHT),"Free inscription refused")
	controller.tick(1)
	check(controller.field!=null and controller.field.field_type=="arcane" and controller.field.use_seconds==40 and controller.field.remaining==120,"Free inscription did not create its real timed rune")
	sm.equip_slot(1,sm.pool.get_skill("pulse"))
	var trigger:=controller.preview(sm.get_slot(1).data,actor)
	check(trigger.rule_id=="arcane_pulse","Free rune cannot respond to a separate manual action")
	check(controller.field.use_seconds==40 and controller.field.remaining==120,"Preview automatically triggered the rune")
	check(sm.use_slot(1,actor,Vector2.RIGHT),"Manual rune trigger refused")
	controller.tick(.5)
	check(controller.field.remaining==80,"Manual trigger did not spend the rune time budget")
	controller.reset_session()
	store.receive("player","fire_stone",2); store.receive("player","frost_salt",1)
	supplies.select_payload(rune,"ember",sm)
	var mp:=actor.mana_component.mp
	check(controller.preview(rune,actor).material_costs=={"fire_stone":1},"Fire rune did not reserve its actual stone")
	check(sm.use_slot(0,actor,Vector2.RIGHT),"Stone inscription refused")
	supplies.select_payload(rune,"frost",sm)
	controller.tick(1)
	check(controller.pending.is_empty() and actor.mana_component.mp==mp and store.count("player","fire_stone")==2 and store.count("player","frost_salt")==1,"Changing payload during preparation consumed resources")
	controller.reset_session(); supplies.select_payload(rune,"ember",sm)
	check(sm.use_slot(0,actor,Vector2.RIGHT),"Material rune could not restart")
	controller.tick(1)
	check(controller.field.field_type=="fire" and controller.field.use_seconds==30 and controller.field.remaining==180 and store.count("player","fire_stone")==1 and supplies.selected.get("inscribe")=="ember","Stone rune did not consume once or preserve its chosen ammunition")
	check(sm.pool.get_skill("fire_sigil").field_type=="fire" and rune.field_type=="arcane","Composition mutated shared definitions")
	controller.reset_session()
	var spray:=sm.pool.get_skill("disperse"); sm.equip_slot(2,spray)
	check(not controller.preview(spray,actor).ready,"Empty sprayer created material from nothing")
	check(supplies.select_payload(spray,"venom",sm),"Known dispersal action required a redundant poison spell unlock")
	mp=actor.mana_component.mp
	check(not sm.use_slot(2,actor,Vector2.RIGHT) and actor.mana_component.mp==mp,"Missing venom still produced a paid cast")
	store.receive_into("player.pack","venom_sprayer",1)
	check(not controller.preview(spray,actor).ready,"Sprayer pulled a bottle directly from the backpack")
	var uid:=store.find_owned("player","venom_sprayer")
	check(store.commit(store.preview("player.pack","player.pocket",uid,1)).accepted,"Bottle could not be prepared in pocket")
	var target:=game.active_enemies[0]
	target.position=actor.position+Vector2(90,0)
	target.process_mode=Node.PROCESS_MODE_INHERIT
	target.set_physics_process(false)
	target.state_chart.process_mode=Node.PROCESS_MODE_DISABLED
	target.actor_context.actions.set_physics_process(false)
	var buffs:=target.get_node("BuffManager") as BuffManager
	buffs.clear_all(); target.health_component.invincible=false
	await frames()
	var channel:=actor.actor_context.spray as SprayChannel
	channel.set_physics_process(false); channel.held_query=Callable(); channel.aim_query=Callable()
	check(sm.use_slot(2,actor,Vector2.RIGHT),"Prepared real spray bottle refused")
	channel.advance(.25); channel.stop()
	check(buffs.has_buff("poison") and store.item(uid).properties.doses==2,"Cone spray did not hit using one actual dose")
	check(supplies.selected.get("disperse")=="venom","Sprayer forced a menu visit after every dose")
	var poison:=buffs.capture_status("poison")
	check(not poison.is_empty() and poison.buff.tick_damage==3,"Default elemental status overwrote the material poison")
	controller.reset_session(); supplies.select_payload(spray,"venom",sm)
	mp=actor.mana_component.mp
	check(sm.use_slot(2,actor,Vector2.RIGHT),"Depletion test could not begin")
	store.pay("player",{"venom_sprayer":1},true)
	channel.advance(.25)
	check(not channel.active and actor.mana_component.mp==mp,"Missing bottle was replaced or charged during windup")
	var registry:=SpellOperationCatalog.default_catalog()
	var disperse:=registry.operation("disperse")
	target.health_component.invincible=false
	buffs.apply_buff(disperse.payload("venom").statuses[0])
	var potent:=disperse.compose(disperse.payload("potent"))
	CombatExecutor.report_hit(actor,target,0,target.position,potent,potent.tags,"potent-check")
	poison=buffs.capture_status("poison")
	check(not poison.is_empty() and poison.buff.tick_damage==6 and poison.buff.duration==8,"Stronger reagent had the same poison as the weak reagent")
	var hp:=target.health_component.hp
	buffs.tick(1)
	check(target.health_component.hp<=hp-6,"Material poison potency did not reach actual periodic damage")
	buffs.clear_all(); target.health_component.invincible=false
	var paralytic:=disperse.compose(disperse.payload("paralytic"))
	hp=target.health_component.hp
	CombatExecutor.report_hit(actor,target,0,target.position,paralytic,paralytic.tags,"paralysis-check")
	check(buffs.prevents_actions() and target.move_speed==0 and not buffs.has_buff("poison"),"Paralytic material did not immobilize without adding poison damage")
	check(not target.actor_context.actions.try_action(Action.melee(target)).accepted and not target.skill_manager.can_act(target),"Paralysis allowed physical or spell actions")
	buffs.tick(2)
	check(not buffs.prevents_actions() and target.move_speed>0 and target.health_component.hp==hp,"Paralysis dealt damage or failed to recover")
	buffs.apply_buff(load("res://content/spell_operations/statuses/paralysis.tres"))
	var water:=disperse.compose(disperse.payload("water"))
	target.health_component.invincible=false
	CombatExecutor.report_hit(actor,target,0,target.position,water,water.tags,"wash-check")
	check(not buffs.prevents_actions(),"Real water spray could not wash away paralysis")
	var trainer:=game.session.actor_for_id("river.enemy.service.trainer")
	CombatExecutor.report_hit(actor,trainer,0,trainer.position,paralytic,paralytic.tags,"neutral-control")
	check(game.session.relations.attitude("river.enemy.service.trainer","player")=="hostile","Non-damaging hostile control left a neutral NPC friendly")
	# Crafting uses the existing gathered herbs/minerals and the same inventory.
	supplies.restrict_crafting=false
	store.receive("player","herb",3); store.receive("player","crystal",2)
	var herbs:=store.count("player","herb")
	check(supplies.craft("paralytic_extract") and store.count("player","herb")==herbs-2 and store.count("player","paralytic_extract")==1,"Gathered ingredients did not produce the actual sprayer reagent")
	store.receive("player","paralytic_sprayer",1)
	controller.reset_session(); supplies.select_payload(spray,"paralytic",sm)
	check(supplies.serialize(true).selected.is_empty(),"Prepared payload leaked into a persistent selection")
	check(game.session.drop_pack("player"),"Backpack drop failed")
	check(controller.preview(spray,actor).ready,"Dropping a backpack hid a prepared pocket bottle")
	var found_caster:=false
	for enemy in game.active_enemies:
		if not enemy.character_definition or enemy.character_definition.id!="river_caster": continue
		found_caster=true
		enemy.position=actor.position
		var npc_controller:=enemy.skill_manager.combinations
		npc_controller.reset_session()
		var initial:=npc_controller.supplies.count("fire_stone")
		var request:=enemy.character_brain.cast("fire_sigil",actor)
		check(request!=null and initial==2,"NPC did not choose a real field reagent through the shared operation")
		if request:
			check(enemy.skill_manager.use_source(request.skill_source,enemy,request.cast_context),"NPC shared inscription refused")
			npc_controller.tick(1)
			check(npc_controller.field and npc_controller.field.field_type=="fire" and npc_controller.supplies.count("fire_stone")==initial-1,"NPC inscribed without consuming its real stone")
			check(GrayriverLoot.snapshot(enemy).materials.get("fire_stone",0)==initial-1,"NPC loot refilled its consumed reagent from the template")
		break
	check(found_caster,"NPC reagent test did not find a real caster")
	check(registry.validation_errors().is_empty(),"Authored spell operation catalog invalid")
	await fixture.close()
	if failures.is_empty(): print("PASS spell operations: canonical loadouts, explicit free/material runes, transactional preparation, real pocket spray, potency, paralysis, cleansing and gathered recipes")
	quit(0 if failures.is_empty() else 1)
