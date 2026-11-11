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
 check(manager.definitions().size()==40 and manager.validate_catalog().is_empty(),"Perk resources are missing, malformed, untyped or cyclic")
 check(manager.get_character_level()==stats.level and manager.get_available_perk_points()==0,"Fresh character has a duplicate level or free perk budget")
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
 # Original spell nodes now load as real typed Resources and enter shared fee/status rules.
 manager.on_deal_damage(SkillMastery.School.DESTRUCTION,5000)
 learn(manager,"destruction_scorch"); learn(manager,"destruction_firestorm")
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
 var saved:=manager.serialize_state(); var points:=manager.get_available_perk_points()
 game._save_progress(); await fixture.close()
 fixture=Fixture.new(self); game=await fixture.boot(true,true)
 manager=game.player.mastery_manager
 check(manager.serialize_state()==saved and manager.get_available_perk_points()==points and game.session.inventory.item(weapon)==null,"Real re-entry lost purchases, granted points or restored dismantled gear")
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
 check(old.get_available_perk_points()==2 and old.get_character_level()==1 and old.has_perk("destruction_scorch"),"Legacy migration erased points/knowledge or fabricated actor levels")
 var migrated:=old.serialize_state(); old.restore_state(migrated)
 check(old.serialize_state()==migrated and old.get_available_perk_points()==2,"Repeated restoration duplicated legacy credit")
 owner.queue_free()
 for i in range(4): await process_frame
 if failures.is_empty(): print("PASS RPG progression: sole earned level/points, typed DAGs and requirements, real stamina/ranged/guard/carry/survival/craft/upgrade/salvage/gathering effects, depletion, rollback guards and actual save/re-entry")
 quit(0 if failures.is_empty() else 1)
