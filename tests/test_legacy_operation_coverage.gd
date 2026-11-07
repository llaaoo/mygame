extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
class Reject extends SkillExecutor:
	func execute(_skill: SkillData,_context: CastContext) -> bool: return false
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func run() -> void:
	var fixture:=Fixture.new(self)
	var game: GrayriverGame=await fixture.boot()
	var actor:=game.player
	var sm:=actor.skill_manager
	var controller:=sm.combinations
	var supplies:=controller.supplies
	var store:=game.session.inventory
	var catalog:=SpellOperationCatalog.default_catalog()
	sm.restrict_actions=false
	actor.position=Vector2(-3500,2000)
	var coverage: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/spell_operations/legacy_coverage.json"))
	check(coverage.entries.size()==RunManager.SKILL_REWARD_IDS.size(),"Historical inventory does not account for all room rewards")
	var seen: Dictionary={}
	for entry: Dictionary in coverage.entries:
		check(entry.legacy in RunManager.SKILL_REWARD_IDS and not seen.has(entry.legacy),"Unknown/duplicate historical coverage entry")
		seen[entry.legacy]=true
		if entry.status=="replaced_by_existing_operation":
			check(catalog.canonical(entry.legacy)==entry.action,"Existing operation replacement missing")
			continue
		if entry.status!="implemented_as_payload":
			check(controller.rules.any(func(rule: SpellCombinationRule): return rule.id==entry.rule and rule.result_skill.get_id()==entry.effect),"Existing replacement missing: "+entry.legacy)
			continue
		sm.equip_slot(4,load("res://gameplay/abilities/data/%s_data.tres"%entry.legacy))
		check(sm.get_slot(4).data.get_id()==entry.action,"Legacy loadout did not migrate into a basic operation: "+entry.legacy)
		check(not sm.knows_action(load("res://gameplay/abilities/data/%s_data.tres"%entry.legacy)),"Current rules still allow the old standalone skill")
		var action:=catalog.operation("attune" if entry.action=="focus" else entry.action).action
		sm.equip_slot(0,action)
		action=sm.get_slot(0).data
		check(supplies.select_payload(action,entry.payload,sm),"Cannot select source: "+entry.legacy)
		store.receive("player",entry.material,4)
		controller.clear_field(); controller.cooldowns.clear(); controller._recovery=0
		actor.get_node("BuffManager").clear_all()
		actor.get_node("SummonManager").clear_all()
		actor.mana_component.mp=999
		if entry.source!="material": check(not controller.preview(action,actor).ready,"Invented absent source: "+entry.legacy)
		var field: FireSigil
		var remnant: SoulRemnant
		if entry.source=="soul":
			remnant=SoulRemnant.new(); game.region_root.add_child(remnant); remnant.position=actor.position
		elif entry.source!="material":
			field=FireSigil.new(); field.caster=actor; field.field_type=entry.source; field.charges=2
			game.region_root.add_child(field); field.position=actor.position; controller.fields.append(field)
		var preview:=controller.preview(action,actor)
		check(preview.ready and preview.material_costs.get(entry.material)==1,"Source/cost preview unavailable: "+entry.legacy+": "+preview.reason)
		var before:=store.count("player",entry.material)
		var mana:=actor.mana_component.mp
		var original:=sm.executor
		var reject:=Reject.new(); sm.add_child(reject); sm.executor=reject
		var context:=CastContext.simple(actor,Vector2.RIGHT,action)
		if action.cast_type=="channel": sm.use_channel_tick("slot_0",actor,context,5)
		else:
			sm.use_source("slot_0",actor,context); controller.tick(2)
		check(store.count("player",entry.material)==before and actor.mana_component.mp==mana and (not field or field.charges==2) and (not remnant or not remnant.spent),"Rejected result leaked resources: "+entry.legacy)
		sm.executor=original; reject.queue_free(); controller._recovery=0; controller.cooldowns.clear()
		context=CastContext.simple(actor,Vector2.RIGHT,action); context.charge_power=.5
		if action.cast_type=="channel": check(sm.use_channel_tick("slot_0",actor,context,5),"Channel pulse refused")
		else:
			check(sm.use_source("slot_0",actor,context),"Accepted source refused: "+entry.legacy)
			check(is_equal_approx(controller.pending.charge_power,.5),"Preparation lost accepted charge power")
			controller.tick(2)
		for i in range(25 if preview.skill.skill_type==SkillData.SkillType.DASH else 3): await physics_frame
		check(store.count("player",entry.material)==before-1 and actor.mana_component.mp<mana,"Completed result did not pay real resources: "+entry.legacy)
		if field: check(field.charges==1,"Result did not consume exactly one selected field charge: "+entry.legacy)
		if remnant: check(not is_instance_valid(remnant) or remnant.spent,"Construct invented an unconsumed soul")
		if preview.skill.skill_type==SkillData.SkillType.SUMMON:
			var summons: Array=actor.get_node("SummonManager").active_summons
			check(summons.size()==1,"No actual summon: "+entry.legacy)
			if not summons.is_empty():
				var hp: int=summons[0].get_node("HealthComponent").hp
				var hit:=CombatExecutor.report_hit(actor,summons[0],99,summons[0].position,null,["physical"],"owned-construct")
				check(not hit.accepted and summons[0].get_node("HealthComponent").hp==hp,"Owner harmed its own temporary construct")
		elif preview.skill.skill_type==SkillData.SkillType.BUFF: check(actor.get_node("BuffManager").has_buff(preview.skill.buff_resource.status_id),"No actual buff: "+entry.legacy)
		if field: field.expire()
		controller.fields.clear()
	# A channel stops at the chosen material boundary; it never emits free pulses.
	var action:=catalog.operation("sustain").action
	sm.equip_slot(0,action); action=sm.get_slot(0).data
	supplies.select_payload(action,"ice_storm",sm)
	var salt:=store.count("player","frost_salt")
	if salt>0: store.pay("player",{"frost_salt":salt})
	store.receive("player","frost_salt",2)
	actor.mana_component.mp=60; controller.cooldowns.clear(); controller._recovery=0
	actor.casting._begin_channel("slot_0",action)
	actor.casting.tick(1.21)
	check(store.count("player","frost_salt")==0 and actor.mana_component.mp==50 and actor.casting._channeling_source.is_empty(),"Channel did not stop after two paid pulses with cumulative MP rounding")
	# Reading an old claimed note backfills techniques, without repeating material rewards.
	var ink:=store.count("player","echo_ink")
	game.progress.claims["river.fire"]=true; game.progress.claims["river.focus"]=true
	game.progress_service._apply_knowledge()
	check(game.progress.actions.has("project") and game.progress.actions.has("shape") and store.count("player","echo_ink")==ink,"Claimed-note knowledge migration repeated rewards or omitted new techniques")

	# Dynamic channel source changes stop before spending the next pulse.
	store.receive("player","frost_salt",2); actor.mana_component.mp=60
	actor.casting._begin_channel("slot_0",action); actor.casting.tick(.4)
	supplies.selected[action.get_id()]="invalid_source"
	actor.casting.tick(.4)
	check(store.count("player","frost_salt")==1 and actor.mana_component.mp==55 and actor.casting._channeling_source.is_empty(),"Channel changed its accepted payload or paid an invalid next pulse")
	# Newly materialized movement still obeys physical walls.
	controller.clear_field(); controller.cooldowns.clear(); controller._recovery=0
	var step:=catalog.operation("step").action; sm.equip_slot(0,step)
	supplies.select_payload(step,"arcane_dash",sm); store.receive("player","crystal",1)
	var rune:=FireSigil.new(); rune.caster=actor; rune.field_type="arcane"; rune.charges=2
	game.region_root.add_child(rune); rune.position=actor.position; controller.fields.append(rune)
	var wall:=StaticBody2D.new(); wall.collision_layer=1; wall.collision_mask=0
	var shape:=CollisionShape2D.new(); var rectangle:=RectangleShape2D.new(); rectangle.size=Vector2(16,160); shape.shape=rectangle; wall.add_child(shape)
	game.region_root.add_child(wall); wall.position=actor.position+Vector2(80,0)
	for i in range(3): await physics_frame
	var origin:=actor.position; actor.mana_component.mp=60
	check(sm.use_source("slot_0",actor,CastContext.simple(actor,Vector2.RIGHT,sm.get_slot(0).data)),"Material step did not start")
	controller.tick(1)
	for i in range(30): await physics_frame
	check(actor.position.x>origin.x+10 and actor.position.x<wall.position.x-8 and rune.charges==1,"Material movement tunneled through a wall or did not consume its source")
	check(catalog.validation_errors().is_empty(),"Operation resources invalid")
	await fixture.close()
	if failures.is_empty(): print("PASS legacy operations: all 28 classified, real sources/payments/results, rejected casts rollback, charge retained, channel exhaustion, claimed-note backfill")
	quit(0 if failures.is_empty() else 1)
