extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const Residents=preload("res://tests/support/resident_service_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func run() -> void:
 var fixture:=Fixture.new(self); var game: GrayriverGame=await fixture.boot(true,true)
 game.session.set_process(false)
 var extension:=Residents.new(); extension.install(game)
 var session:=game.session; var store:=session.inventory; var actor:=game.player
 var aida:=session.actor_for_id("river.aida") as ServiceNPC
 var merchant:=session.actor_for_id(TownServices.MERCHANT) as ServiceNPC
 for npc_id in [TownServices.MERCHANT,"river.aida",Residents.MERCHANT,Residents.TRAINER,game.town_services.training.actor_id]:
  var npc:=session.actor_for_id(npc_id) as ServiceNPC
  npc.set_physics_process(false); npc.actor_context.actions.set_physics_process(false)
 var extras: Dictionary={}
 for person in GrayriverStories.PEOPLE.values(): extras[person.claim]=true
 check(session.conversations.catalog.validation_errors(game.catalog,extras).is_empty(),"Extended service catalog failed actual content validation")
 var extra_shop:=game.residents.adapter_for(Residents.MERCHANT)
 var extra_teacher:=game.residents.adapter_for(Residents.TRAINER)
 check(extra_shop.market.actor_id==Residents.MERCHANT and extra_shop.training==null and extra_teacher.training.actor_id==Residents.TRAINER and extra_teacher.market==null,"Service adapter silently substituted the primary merchant/trainer")
 store.receive("player","coin",30)
 actor.position=session.actor_for_id(Residents.MERCHANT).position+Vector2(0,35)
 var primary: Dictionary=store.snapshot_owners([TownServices.MERCHANT]).containers
 var arrow:=store.find_owned(Residents.MERCHANT,"arrow")
 check(extra_shop.transact(arrow,false).accepted and store.count(Residents.MERCHANT,"arrow")==5 and store.snapshot_owners([TownServices.MERCHANT]).containers==primary,"Second merchant traded the wrong owner's stock")
 actor.position=session.actor_for_id(Residents.TRAINER).position+Vector2(0,35)
 var old_purse:=store.count(game.town_services.training.actor_id,"coin")
 extra_teacher._teach("blade_breaker")
 check(actor.actor_context.martial.learned.has("blade_breaker") and store.count(Residents.TRAINER,"coin")==8 and store.count(game.town_services.training.actor_id,"coin")==old_purse,"Second teacher charged the wrong purse or taught from a fallback catalog")
 game.ui.close_modal()
 # Read-only projection is also the actual resource configuration source.
 var needs:=actor.actor_context.actions.needs; needs.hydration=10; needs.fatigue=90
 ActorProgression.refresh_stamina(actor)
 var projection:=ActorProgression.stamina_values(actor)
 check(is_equal_approx(projection.base_regeneration,10) and is_equal_approx(projection.regeneration,1.75) and is_equal_approx(actor.actor_context.actions.stamina.regeneration,projection.regeneration),"Effective stamina projection disagrees with real dehydration/fatigue settlement")
 needs.hydration=100; needs.fatigue=0; ActorProgression.refresh_stamina(actor)
 # Typed leads use actual destinations; no fact/knowledge/map mutation.
 actor.position=aida.position+Vector2(0,35)
 var handle:=session.conversations.begin("river.aida")
 var visited:=game.progress.visited.duplicate(); var claims:=game.progress.claims.duplicate()
 var response:=session.conversations.choose(handle.token,"routes")
 check(response.accepted and response.response.contains("方向") and game.progress.visited==visited and game.progress.claims==claims,"NPC navigation lead fabricated exploration or omitted actual routing")
 var record_id:="npc.topic.river.aida.routes"
 var record: Dictionary={}
 for entry in game.progress.journal:
  if entry.id==record_id: record=entry
 check(not record.is_empty() and game.record_text(record)==session.conversations.response_for("river.aida",session.conversations.catalog.profile("river.aida").topic("routes"))+"\n交谈线索；地图仍只记录亲自踏足的地点。","Journal lost typed live lead rendering")
 var bad:=session.conversations.catalog.duplicate() as NpcCatalog
 bad.profiles=[]
 var profile:=session.conversations.catalog.profile("river.aida").duplicate() as NpcProfile
 var topic:=profile.topic("routes").duplicate() as NpcTopic; topic.required_claims=PackedStringArray(["unknown.claim"]); profile.topics=[topic]; bad.profiles=[profile]
 check(not bad.validation_errors(game.catalog,extras).is_empty(),"Unknown NPC prerequisite passed cross-catalog validation")
 topic.required_claims=[]; var hint:=ExplorationNavigationHint.new(); hint.target_claim="unknown.lead"; topic.navigation_hints=[hint]
 check(not bad.validation_errors(game.catalog,extras).is_empty(),"Unknown NPC navigation reference passed validation")
 profile=session.conversations.catalog.profile(Residents.MERCHANT).duplicate() as NpcProfile
 profile.market=null; bad.profiles=[profile]
 check(not bad.validation_errors(game.catalog,extras).is_empty(),"Market service without its own market configuration passed validation")
 # Personal objectives reuse the saved tracker and actual, discovered sources.
 var favor_id:="npc.favor.river.aida/herbs"
 check(session.conversations.choose(handle.token,"herbs","accept").accepted,"Could not accept a real personal objective")
 if store.count("player","herb")>0: store.pay("player",{"herb":store.count("player","herb")})
 game.guidance.pin(favor_id)
 check(game.progress.tracked_quest==favor_id and not game.guidance.tracked().is_empty(),"Personal objective did not use the same tracker as formal quests")
 var stations: Array[Dictionary]=[]
 for region: ExplorationRegionData in game.catalog.regions.values():
  for station in region.survival_stations:
   if station.harvest.has("herb"): stations.append({"region":region,"station":station})
 check(not stations.is_empty(),"No real herb source exists")
 if not stations.is_empty():
  var source: Dictionary=stations[0]
  if source.region.id=="camp": game.progress.claims["fog.%d.%d"%[floori(source.station.pos.x/512),floori(source.station.pos.y/512)]]=true
  else: game.progress.visited[source.region.id]=true
  var goal:=game.guidance.goal_for(favor_id)
  check(goal.title.begins_with("收集") and goal.known,"Personal tracker did not suggest a genuinely known gatherable source")
 store.receive("player","herb",2)
 check(game.guidance.tracked().title.contains("交付"),"Acquired goods did not change the next step to actual delivery")
 check(session.conversations.choose(handle.token,"herbs","deliver").accepted and game.guidance.goal_for(favor_id).is_empty(),"Completed favor remained an actionable tracking objective")
 # Distinct shared-actor self-preservation, driven by actual hostility.
 actor.position=aida.position+Vector2(45,0); session.relations.set_attitude("river.aida","player","hostile")
 aida._clock=0; aida._physics_process(.3)
 check(aida.actor_context.actions.mode!="attack" and aida.actor_context.actions.movement.dot(aida.position-actor.position)>0,"Civilian chased/attacked instead of choosing a collision-aware retreat")
 var trainer:=session.actor_for_id(game.town_services.training.actor_id) as ServiceNPC
 actor.position=trainer.position+Vector2(40,0); session.relations.set_attitude(trainer.actor_context.id,"player","hostile")
 trainer._clock=0; trainer._physics_process(.3)
 check(trainer.actor_context.actions.mode=="attack","Defensive trainer did not use the shared physical action executor")
 session.relations.set_attitude("river.aida","player","neutral"); session.relations.set_attitude(trainer.actor_context.id,"player","neutral"); trainer.actor_context.actions.cancel()
 # Re-entry preserves independent purses, tracking and the completed one-time exchange.
 var saved:=session.conversations.snapshot(); var extra_money:=store.count(Residents.MERCHANT,"coin")
 game._save_progress(); await fixture.close(); fixture=Fixture.new(self); game=await fixture.boot(true,true)
 game.session.set_process(false); session=game.session; store=session.inventory; actor=game.player
 check(session.conversations.snapshot()==saved and game.progress.tracked_quest==favor_id and store.count(Residents.MERCHANT,"coin")==extra_money and store.count(Residents.TRAINER,"coin")==8,"Re-entry lost independent service ownership or objective state")
 var prior_arrows:=store.count(TownServices.MERCHANT,"arrow")
 check(session.production.start("town.arrows").accepted,"Could not schedule living off-region producer")
 await fixture.travel("river_archive")
 check(session.actor_for_id(TownServices.MERCHANT)==null,"Region fixture retained a live merchant node")
 session.advance_rest_time(60)
 check(store.count(TownServices.MERCHANT,"arrow")==prior_arrows+6,"Unloading a living producer was treated as death")
 await fixture.travel("camp")
 # A producer dies during the first batch notification: all further batches/orders stop.
 merchant=session.actor_for_id(TownServices.MERCHANT) as ServiceNPC
 actor.position=merchant.position+Vector2(-35,0)
 var death_favor:="npc.favor.river.merchant/charcoal"
 var death_handle:=session.conversations.begin(TownServices.MERCHANT)
 check(death_handle.accepted and session.conversations.choose(death_handle.token,"charcoal","accept").accepted,"Could not accept the soon-unavailable personal objective")
 game.guidance.pin(death_favor)
 var production:=session.production; var arrows:=store.count(TownServices.MERCHANT,"arrow")
 var metal:=store.count(TownServices.MERCHANT,"metal_scrap"); var charcoal:=store.count(TownServices.MERCHANT,"charcoal")
 check(production.start("town.arrows",3).accepted and production.start("town.fire_stone",2).accepted,"Could not schedule lifecycle test work")
 var observer:=func(fact: Dictionary):
  if fact.kind=="craft_committed" and fact.source==TownServices.MERCHANT and not merchant.health_component.is_dead:
   CombatExecutor.report_hit(actor,merchant,10000,merchant.position,null,["physical","melee"],"coherence.worker.death")
 session.facts.committed.connect(observer)
 store.clock_seconds+=180; production.advance(); session.facts.committed.disconnect(observer)
 check(merchant.health_component.is_dead and production.snapshot().jobs.is_empty() and store.count(TownServices.MERCHANT,"arrow")==arrows+6 and store.count(TownServices.MERCHANT,"metal_scrap")==metal-1 and store.count(TownServices.MERCHANT,"charcoal")==charcoal-1,"Reentrant producer death created later batches or consumed extra materials")
 check(not production.start("town.arrows").accepted and production.status("town.arrows").reason=="producer_dead","Dead producer accepted work")
 check(game.guidance.goal_for(death_favor).get("terminal",false) and not game.guidance.route_target(game.guidance.tracked()).is_finite(),"Dead personal objective still offered a delivery arrow")
 check(game.progress.journal.any(func(record: Dictionary): return record.id=="service.production.town.arrows" and record.text.contains("遗骸") and not record.text.contains("返回整修铺购买")),"Reentrant death advertised a live shop after production terminated")
 var death_state:=session.snapshot(); death_state.production={"schema":1,"jobs":{"town.arrows":{"due":store.clock_seconds+5,"batches":2,"blocked":false}}}
 check(session.restore(death_state) and production.snapshot().jobs.is_empty(),"Old save retained unfinished dead-producer work")
 var after_death:=store.snapshot(); session.advance_rest_time(360); production.advance()
 check(store.snapshot()==after_death,"Rest transformed a dead producer's actual corpse stock")
 game._save_progress(); await fixture.close(); fixture=Fixture.new(self); game=await fixture.boot(true,true)
 check(game.session.production.snapshot().jobs.is_empty() and game.session.actor_for_id(TownServices.MERCHANT)==null,"Dead production resumed after real save/re-entry")
 await fixture.close(); extension.release()
 if failures.is_empty(): print("PASS world coherence: independent merchant/course purses and re-entry, effective stamina, typed NPC leads and validation, shared personal objective tracking and real gathering, civilian retreat/trainer defense, reentrant producer death/legacy job recovery/rest/save conservation")
 quit(0 if failures.is_empty() else 1)
