extends SceneTree
const Awake=preload("res://tests/support/awakened_actor_fixture.gd")
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func learn(manager: SkillMasteryManager,id: String) -> void:
 check(manager.unlock_perk(id),"Could not learn a qualified perk: "+id+" / "+manager.unlock_reason(id))
func run() -> void:
 var fixture:=Fixture.new(self); var game: GrayriverGame=await fixture.boot(true,true)
 var actor:=game.player; var stats:=actor.stats_component; var manager:=actor.mastery_manager
 var store:=game.session.inventory; var actions:=actor.actor_context.actions
 check(manager.definitions().size()==62 and manager.validate_catalog().is_empty(),"Perk resources are missing, malformed, untyped or cyclic")
 check(manager.get_character_level()==stats.level and manager.get_available_perk_points()==0,"Fresh character has a duplicate level or free perk budget")
 check(manager.get_active_schools()==[5,6,7,8,0,3] and manager.get_active_schools().all(func(school):return manager.get_perks_for_school(school).size()==7),"Current routes were not consolidated into six complete seven-node branches")
 check(not manager.can_unlock_perk("destruction_scorch") and manager.unlock_reason("spell_discipline").contains("觉醒"),"Legacy nodes remain purchasable or ordinary growth bypasses awakening")
 actions.stamina.current=60; stats.attribute_points=1
 check(stats.spend_attribute_point("endurance") and actions.stamina.maximum==102 and actions.stamina.current==60,"Endurance investment failed to change stamina immediately or refilled it")
 var buffs:=actor.get_node("BuffManager") as BuffManager
 var temporary:=Buff.new(); temporary.status_id="test.endurance"; temporary.duration=1; temporary.stat_modifiers={"endurance":4}
 buffs.apply_buff(temporary,actor)
 check(actions.stamina.maximum==110 and actions.stamina.current==60,"Effective endurance did not use the shared stamina projection")
 buffs.tick(1.1)
 check(actions.stamina.maximum==102 and actions.stamina.current==60,"Expired primary contribution left stamina or created recovery")
 CombatExecutor.report_exp_bonus(actor,100)
 check(stats.level==2 and stats.attribute_points==3 and manager.get_character_level()==2 and manager.get_available_perk_points()==1,"Character upgrade did not give the sole attribute/perk budget")
 var before:=manager.serialize_state()
 check(not manager.unlock_perk("economical_strokes") and before==manager.serialize_state(),"Failed requirements consumed points or learned a child node")
 learn(manager,"battle_conditioning")
 check(actions.stamina.maximum==117 and actions.stamina.current==60 and manager.get_available_perk_points()==0,"Stamina perk was cosmetic, healed stamina or charged wrong points")
 check(not manager.unlock_perk("steadfast_guard") and not manager.unlock_perk("battle_conditioning"),"Perk budget or duplicate learning was bypassed")
 # Controlled earned XP/knowledge fixture; every purchase and inventory effect is real.
 CombatExecutor.report_exp_bonus(actor,500000)
 for kind in ["melee_hit","hit_blocked","recipe_crafted","resource_harvested"]: manager.record_activity(kind,1000)
 var borrowed:=Buff.new(); borrowed.status_id="test.borrowed_strength"; borrowed.duration=1; borrowed.stat_modifiers={"strength":20}
 buffs.apply_buff(borrowed,actor)
 var perk_points:=manager.get_available_perk_points()
 check(stats.effective_stat("strength")>=30 and not manager.unlock_perk("economical_strokes") and manager.get_available_perk_points()==perk_points,"Temporary attributes bypassed permanent perk requirements")
 buffs.tick(1.1)
 for key in Buff.PRIMARY_STATS:
  while int(stats.get(key))<14: check(stats.spend_attribute_point(key),"Could not invest earned attribute points")
 check(manager.get_character_level()==stats.level,"Practice created another character level authority")
 learn(manager,"economical_strokes"); learn(manager,"art_focus"); learn(manager,"forceful_impact")
 learn(manager,"steadfast_guard"); learn(manager,"guarded_breath"); learn(manager,"counter_mastery"); learn(manager,"light_step"); learn(manager,"deep_reserve")
 actor.actor_context.martial.learn("blade_breaker")
 var strike:=MartialArts.definition("blade_breaker").profile
 var perk_cost:=actions.attack_stamina_cost(strike,true)
 check(perk_cost<strike.stamina_cost*actions.burden_cost()*actions.activity_efficiency(SkillMastery.School.MELEE),"Art efficiency did not enter the physical cost query")
 actions.guarding=true; actions.stamina.delay=.5; var current:=actions.stamina.current
 actions.advance(.25); check(actions.stamina.current==current,"Guard perk bypassed the post-consumption delay")
 actions.advance(.5); check(is_equal_approx(actions.stamina.current,current+actions.stamina.regeneration*.25*.2),"Guard perk recovered the wrong amount across its delay boundary")
 actions.guarding=false
 store.receive("player","river_sabre",1); store.equip("player",store.find_owned("player","river_sabre"))
 var guard:=Action.new(); guard.action_type=Action.ActionType.GUARD; guard.source=actor; guard.direction=Vector2.RIGHT; guard.params={"held":true}
 actions.try_action(guard)
 var foe:=game.active_enemies[0]; foe.position=actor.position+Vector2(45,0)
 var hit:=HitContext.new(foe,actor,20,actor.position,null,["physical","melee"],"test.rpg.parry")
 var result:=HitResult.new(); result.accepted=true; result.damage_accepted=true; result.status_accepted=true
 actions.defend(hit,result,20)
 check(result.parried and actions.counter_remaining>0 and actions.mode=="idle","Defense perk fabricated an automatic counter or broke actual parry eligibility")
 var counter:=Action.melee(actor); counter.direction=Vector2.RIGHT
 check(actions.try_action(counter).accepted and actions.counter_strike and is_equal_approx(actions.profile.damage_multiplier,preload("res://content/frontier/equipment/river_sabre.tres").moveset.attacks[0].damage_multiplier*1.5),"Counter perk did not modify the manually accepted counter profile")
 actions.cancel()
 actions.stamina.current=100
 var dodge:=Action.new(); dodge.action_type=Action.ActionType.DODGE; dodge.source=actor; dodge.direction=Vector2.RIGHT
 var dodge_cost:=20*actions.burden_cost()*float(ActorProgression.values(actor).dodge_multiplier)
 check(actions.try_action(dodge).accepted and is_equal_approx(actions.stamina.current,100-dodge_cost),"Agility and dodge perk did not enter the actual accepted resource cost")
 actions.cancel()
 var bow:=preload("res://content/frontier/equipment/river_bow.tres") as EquipmentData
 var damage:=ActorCombatModel.weapon_damage(actor,bow.moveset.attacks[0])
 stats.modify_stat("strength",1)
 check(ActorCombatModel.weapon_damage(actor,bow.moveset.attacks[0])==damage,"Strength incorrectly substituted for ranged agility")
 stats.modify_stat("agility",1)
 check(ActorCombatModel.weapon_damage(actor,bow.moveset.attacks[0])>damage,"Agility did not improve actual arrow damage")
 # Learning during a held cast invalidates that exact plan without spending.
 game.progress.actions.inscribe=true; game._apply_knowledge()
 var rune:=SpellOperationCatalog.default_catalog().operation("inscribe").action
 check(Awake.awaken(actor),"Spell perk phase requires explicit awakened eligibility")
 actor.skill_manager.equip_source("left",rune,{"payload":"arcane","modifier":"","uid":""})
 var mana_before:=actor.mana_component.mp; var inventory_before:=store.snapshot()
 check(actor.skill_manager.use_source("left",actor,CastContext.simple(actor,Vector2.RIGHT,rune)),"Could not prepare a real cast for revision validation")
 learn(manager,"tool_familiarity")
 actor.skill_manager.combinations.tick(1)
 check(actor.mana_component.mp==mana_before and store.snapshot()==inventory_before and actor.skill_manager.combinations.fields.is_empty(),"Changed perk revision spent a stale cast or created its field")
 actor.skill_manager.combinations.tick(.4)
 learn(manager,"arrow_fletcher"); learn(manager,"salvage_eye"); learn(manager,"careful_smith")
 var supplies:=actor.skill_manager.combinations.supplies
 supplies.known_recipes.arrows=true
 store.receive("player","charcoal",5); store.receive("player","metal_scrap",10)
 var arrows:=store.count("player","arrow"); var material:=store.count("player","metal_scrap")
 check(supplies.craft("arrows") and store.count("player","arrow")==arrows+7 and store.count("player","metal_scrap")==material-1,"Ammunition perk preview/output/payment diverged")
 # Partial-output capacity failure rolls back material, output, UID state and practice.
 store.receive_into("player.pocket","arrow",store.definitions.arrow.max_stack-3-store.count("player","arrow"))
 store.receive_into("player.pocket","river_shield",1000); store.receive_into("player.pack","river_shield",1000)
 var full_inventory:=store.snapshot(); var full_progress:=manager.serialize_state()
 check(not supplies.craft("arrows") and store.snapshot()==full_inventory and manager.serialize_state()==full_progress,"Partial boosted craft leaked output, material or practice on capacity failure")
 store.pay("player",{"river_shield":store.count("player","river_shield")})
 store.receive("player","river_sabre",1); store.receive("player","coin",20)
 var weapon:=store.find_owned("player","river_sabre")
 var coins:=store.count("player","coin")
 check(store.upgrade_cost("player",weapon).coin==3 and store.upgrade_instance("player",weapon).accepted and store.count("player","coin")==coins-3 and store.item(weapon).properties.upgrade_level==1,"Upgrade perk bypassed the real UID/cost boundary")
 material=store.count("player","metal_scrap")
 check(store.dismantle_instance("player",weapon).accepted and store.item(weapon)==null and store.count("player","metal_scrap")==material+4,"Salvage perk failed or duplicated the upgraded item")
 learn(manager,"field_lore"); learn(manager,"pack_habit"); learn(manager,"botanical_eye")
 check(ActorProgression.values(actor).carry_bonus==(stats.effective_stat("strength")-10)*2+10,"Carry capacity ignored permanent progression")
 var ordinary:=SurvivalNeeds.new(); var practiced:=SurvivalNeeds.new()
 ordinary.tick(600,10); practiced.tick(600,10,false,1+ActorProgression.modifier(actor,"survival.needs"))
 check(practiced.hydration>ordinary.hydration and practiced.fatigue<ordinary.fatigue,"Survival perk was not applied to actual need rates")
 var station: ExplorationInteractable; var spec: SurvivalStationData
 for node in game.region_root.get_children():
  if node is ExplorationInteractable and node.has_meta("survival_station"):
   var candidate:=node.get_meta("survival_station") as SurvivalStationData
   if candidate.kind=="forage" and candidate.harvest.has("herb"): station=node; spec=candidate; break
 check(station!=null,"Authored herb gathering point missing")
 if station:
  actor.position=station.position+Vector2(0,20); game.survival.inspect(station,spec)
  var herb:=store.count("player","herb")
  check(actor.field_work.start_selected(),"Qualified herb gathering refused")
  actor.field_work.tick(float(actor.field_work.pending.duration)+.1)
  check(store.count("player","herb")==herb+int(spec.harvest.herb)+1 and game.survival.needs.harvests.has(spec.id),"Herb perk fabricated no real output or bypassed depletion")
  game.survival.inspect(station,spec)
  check(not actor.field_work.start_selected(),"Exhausted resource point could be farmed again immediately")
  actor.field_work.close_panel()
 # Current operation routes replace the old spell-specific purchase entry.
 manager.on_deal_damage(SkillMastery.School.DESTRUCTION,5000)
 learn(manager,"spell_discipline")
 store.receive_into("player.pocket","fire_stone",1)
 actor.skill_manager.shortcuts.set_selection("left",{"payload":"ember","modifier":"","uid":""})
 var plan:=actor.skill_manager.preview_source("left")
 check(plan.ready and plan.cost==7,"Fire perk did not modify the actual material operation fee")
 mana_before=actor.mana_component.mp
 check(actor.skill_manager.use_source("left",actor,CastContext.simple(actor,Vector2.RIGHT,rune)),"Qualified fire rune refused after learning a spell perk")
 actor.skill_manager.combinations.tick(1)
 check(actor.mana_component.mp==mana_before-7 and store.count("player","fire_stone")==0 and actor.skill_manager.combinations.fields.size()==1,"Spell perk consumed the wrong mana/material or auto-created an extra cast")
 learn(manager,"provisioned_recovery")
 store.receive("player","ration",1)
 var rations:=store.count("player","ration"); var before_food:=manager.serialize_state()
 game.survival.begin_eating("ration"); actor.field_work.tick(2); actor.field_work.close_panel()
 ActorProgression.refresh_stamina(actor)
 check(store.count("player","ration")==rations-1 and game.survival.needs.meal_remaining>0 and actions.stamina.regeneration>=ActorProgression.values(actor).stamina_regeneration+2,"Food perk did not require a real consumed provision")
 buffs.tick(250); ActorProgression.refresh_stamina(actor)
 check(game.survival.needs.meal_remaining==0 and is_equal_approx(actions.stamina.regeneration,ActorProgression.values(actor).stamina_regeneration) and manager.serialize_state()==before_food,"Expired food retained perk recovery or food use farmed character practice")
 actor.actor_context.reward_eligible=false
 var no_rewards:=manager.serialize_state(); manager.record_activity("recipe_crafted",1000)
 check(manager.serialize_state()==no_rewards,"No-reward rehearsal granted progression")
 actor.actor_context.reward_eligible=true
 # Additional earned-XP fixture funds the added routes; spending still uses the sole real budget.
 while manager.get_available_perk_points()<12:
  CombatExecutor.report_exp_bonus(actor,maxi(1,stats.exp_to_next-stats.experience))
 # Additional route consumers: source-bound field budget, physical coating, batch manufacture and finite professional harvest.
 var existing_field:=actor.skill_manager.combinations.field
 var existing_life:=existing_field.remaining
 learn(manager,"sigil_foundations"); learn(manager,"sigil_economy")
 check(existing_field.remaining==existing_life,"Buying field perks retroactively refilled an existing field")
 var field_plan:=actor.skill_manager.preview_source("left")
 # The prior stone was spent: explicitly choose the known material-free rune, never auto-substitute.
 actor.skill_manager.shortcuts.set_selection("left",{"payload":"arcane","modifier":"","uid":""})
 field_plan=actor.skill_manager.preview_source("left")
 var budget:=field_plan.field_budget()
 check(is_equal_approx(budget.duration,144) and is_equal_approx(budget.use_seconds,34),"Field perk preview did not derive 120x1.2 and 40x.85")
 actor.skill_manager.combinations.tick(10)
 check(actor.skill_manager.use_source("left",actor,CastContext.simple(actor,Vector2.RIGHT,rune)),"Qualified perk rune refused")
 actor.skill_manager.combinations.tick(1)
 var sigil:=actor.skill_manager.combinations.field
 check(is_equal_approx(sigil.initial_duration,144) and is_equal_approx(sigil.use_seconds,34),"Actual rune disagreed with field-budget preview")
 var life:=sigil.remaining
 check(sigil.consume(actor,sigil.revision,77777) and is_equal_approx(sigil.remaining,life-34),"Combination did not consume the perk-adjusted real field energy")
 learn(manager,"coating_care"); learn(manager,"elemental_finisher")
 learn(manager,"workshop_rhythm"); learn(manager,"coating_workflow"); learn(manager,"alchemical_batch")
 supplies.known_recipes.fire_rag=true
 store.receive("player","resin",2); store.receive("player","charcoal",2); store.receive("player","cloth",2)
 var before_rags:=store.count("player","fire_rag"); var before_resin:=store.count("player","resin")
 check(supplies.craft("fire_rag") and store.count("player","fire_rag")==before_rags+2 and store.count("player","resin")==before_resin-1,"Alchemy batch did not agree with real full-input/two-output transaction")
 check(supplies.recycle_preview("fire_rag").is_empty(),"Bonus consumables can be reversed into a lossless resource/practice loop")
 store.receive("player","river_staff",1); var coated_uid:=store.find_owned("player","river_staff")
 store.equip("player",coated_uid)
 var rag_uid:=store.find_owned("player","fire_rag")
 if store.locate(rag_uid)!="player.pocket": game.inventory_actions.transfer(rag_uid,"player.pocket",1)
 actions.cancel(); actions.stamina.current=100
 var use:=actor.actor_context.item_actions; use.set_physics_process(false)
 check(use.begin("fire_rag"),"Qualified physical coating refused")
 use.advance(2)
 var coating:=store.coating_state(coated_uid)
 check(not coating.is_empty() and is_equal_approx(coating.expires_at-store.clock_seconds,84),"New UID coating did not include both maintenance perks")
 check(WeaponEnchantment.definition("flame").release_value(actor)==21 and WeaponEnchantment.definition("flame").release_damage==18,"Release perk missed the actual common query or mutated shared chemistry")
 # An actual manual technique releases the same real coating into a travelling wave.
 actor.position=Vector2(-4000,800); foe.position=actor.position+Vector2(210,0)
 # Keep collision registered for the travelling-wave query; only the static
 # target's decisions are frozen, rather than disabling its whole physics body.
 foe.process_mode=Node.PROCESS_MODE_INHERIT; foe.set_process(false); foe.set_physics_process(false)
 foe.state_chart.process_mode=Node.PROCESS_MODE_DISABLED; foe.get_node("ActorComponents").process_mode=Node.PROCESS_MODE_DISABLED
 for i in range(3): await physics_frame
 var wave_hp:=foe.health_component.hp; var wave_mp:=actor.mana_component.mp
 actor.actor_context.martial.learn("staff_sweep")
 actions.cancel(); actions.stamina.current=100
 var release:=Action.new(); release.action_type=Action.ActionType.TECHNIQUE; release.skill_id="staff_sweep"; release.direction=Vector2.RIGHT; release.params={"release_enchantment":true}
 check(actions.try_action(release).accepted,"Qualified element technique refused its real coating")
 actions.advance(.6)
 for i in range(40): await physics_frame
 print("PERK_WAVE ",JSON.stringify({"before":wave_hp,"after":foe.health_component.hp,"expected":ActorCombatModel.incoming_damage(foe,21),"coating":store.coating_state(coated_uid),"mp_before":wave_mp,"mp_after":actor.mana_component.mp,"position":foe.position,"mode":actions.mode}))
 check(store.coating(coated_uid)==null and actor.mana_component.mp==wave_mp and wave_hp-foe.health_component.hp==ActorCombatModel.incoming_damage(foe,21),"Actual wave did not apply the perk damage once, consume its coating or preserve MP")
 coating=store.coating_state(coated_uid)
 check(not manager.can_unlock_perk("projection_rhythm") and manager.unlock_reason("projection_rhythm").contains("先掌握"),"Route perk granted unavailable operation knowledge")
 game.progress.actions.project=true; game._apply_knowledge(); learn(manager,"projection_rhythm")
 check(is_equal_approx(CastCostPolicy.cooldown(SpellOperationCatalog.default_catalog().operation("project").action,actor,5),4.25),"Operation-specific rhythm missed the actual cooldown policy")
 var before_hunter:=manager.serialize_state()
 check(not manager.unlock_perk("careful_harvester") and manager.serialize_state()==before_hunter,"Hunter perk bypassed separate professional knowledge")
 actor.actor_context.fieldcraft.learn("player","skinning")
 learn(manager,"careful_harvester")
 var hound_id:="river.enemy.camp.fieldcraft.hound.v1"
 var hound: Enemy
 for candidate in game.active_enemies:
  if candidate.actor_context.id==hound_id: hound=candidate; break
 check(hound!=null,"Original finite hound missing")
 if hound:
  actor.position=hound.position+Vector2(25,0); hound.take_damage(1000)
  for i in range(3): await process_frame
  var raw: Dictionary=store.entries(hound_id+".anatomy").filter(func(row):return row.definition=="raw_hide")[0]
  var part: Dictionary=raw.properties.harvest.duplicate(true)
  store.receive("player","field_knife",1); var knife:=store.find_owned("player","field_knife")
  var hides:=store.count("player","beast_hide")
  var expected:=store.anatomy_outputs("player",part)
  check(expected.beast_hide==int(part.outputs.beast_hide)+1 and store.process_anatomy("player",hound_id,raw.uid,false).accepted and store.item(raw.uid)!=null,"Hunter preview mutated/deleted the real part")
  check(game.loot.harvesting.complete(hound_id,raw.uid,part,knife) and store.item(raw.uid)==null and store.count("player","beast_hide")==hides+int(expected.beast_hide),"Qualified professional harvest disagreed with boosted preview")
  check(not game.loot.harvesting.complete(hound_id,raw.uid,part,knife),"Hunter perk duplicated an already-consumed anatomical UID")
 var saved:=manager.serialize_state(); var points:=manager.get_available_perk_points()
 game._save_progress(); await fixture.close()
 fixture=Fixture.new(self); game=await fixture.boot(true,true)
 manager=game.player.mastery_manager
 check(manager.serialize_state()==saved and manager.get_available_perk_points()==points and game.session.inventory.item(weapon)==null and game.session.inventory.coating_state(coated_uid)==coating,"Real re-entry lost purchases, granted points or restored dismantled gear")
 var invalid:=saved.duplicate(true); invalid.unlocked_perks["5"].append("battle_conditioning")
 check(not SkillMasteryManager.valid_state(invalid),"Save accepted duplicate purchased nodes")
 invalid=saved.duplicate(true); invalid.unlocked_perks["5"].append("unknown.perk")
 check(not SkillMasteryManager.valid_state(invalid),"Save accepted unknown perk")
 invalid=saved.duplicate(true); invalid.masteries["5"].xp=INF
 check(not SkillMasteryManager.valid_state(invalid),"Save accepted nonfinite practice XP")
 await fixture.close()
 # Legacy school-local points migrate once, without borrowing character levels from mastery totals.
 var owner:=Node2D.new(); var legacy_stats:=StatsComponent.new(); legacy_stats.name="StatsComponent"; owner.add_child(legacy_stats)
 var health:=HealthComponent.new(); health.name="HealthComponent"; owner.add_child(health); root.add_child(owner)
 var old:=SkillMasteryManager.new(); owner.add_child(old); old.setup(owner)
 var legacy: Dictionary={"masteries":{"0":{"level":5,"xp":0.0,"xp_to_next":45.0,"perk_points":2}},"unlocked_perks":{"0":["destruction_scorch"]}}
 old.restore_state(legacy)
 check(old.get_available_perk_points()==2 and old.get_character_level()==1 and old.has_perk("destruction_scorch") and old.get_legacy_perks().size()==1 and is_equal_approx(old.get_modifier_value("damage.fire"),.15) and not old.can_unlock_perk("destruction_firestorm"),"Legacy migration erased points/knowledge or fabricated actor levels")
 var migrated:=old.serialize_state(); old.restore_state(migrated)
 check(old.serialize_state()==migrated and old.get_available_perk_points()==2,"Repeated restoration duplicated legacy credit")
 owner.queue_free()
 for i in range(4): await process_frame
 if failures.is_empty(): print("PASS RPG progression: sole earned level/points, typed DAGs and requirements, real stamina/ranged/guard/carry/survival/craft/upgrade/salvage/gathering effects, depletion, rollback guards and actual save/re-entry")
 quit(0 if failures.is_empty() else 1)
