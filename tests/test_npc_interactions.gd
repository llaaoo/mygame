extends SceneTree
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func run() -> void:
 var fixture:=Fixture.new(self); var game: GrayriverGame=await fixture.boot(true,true)
 var domain:=game.session.conversations; var store:=game.session.inventory; var relations:=game.session.relations
 var merchant_id:=TownServices.MERCHANT; var merchant:=game.session.actor_for_id(merchant_id) as ServiceNPC
 var aida:=game.session.actor_for_id("river.aida") as ServiceNPC
 check(domain.catalog.profiles.size()>=3 and domain.catalog.validation_errors().is_empty(),"NPC definitions invalid or missing actual town residents")
 for profile in domain.catalog.profiles:
  if profile.region_id!=game.region_id: continue
  var npc:=game.session.actor_for_id(profile.actor_id) as ServiceNPC
  check(npc!=null and npc.character_definition==profile.character and npc.actor_context.items==store,"NPC is a marker or uses a duplicate actor/inventory model")
  npc.set_physics_process(false); npc.actor_context.actions.set_physics_process(false)
 game.player.position=merchant.position+Vector2(-35,0)
 var first:=domain.begin(merchant_id)
 check(first.accepted,"Real merchant conversation refused: "+str(first))
 var known:=game.progress.visited.duplicate(); var claims:=game.progress.claims.duplicate()
 check(domain.choose(first.token,"supply").accepted and domain.seen(merchant_id,"supply"),"Information response was not remembered")
 check(game.progress.visited==known and game.progress.claims==claims,"Rumor fabricated exploration or world completion")
 var score:=relations.disposition(merchant_id,"player")
 check(domain.choose(first.token,"supply").accepted and relations.disposition(merchant_id,"player")==score,"Repeated talk farmed trust")
 var before:=store.snapshot()
 check(domain.choose(first.token,"charcoal","accept").accepted and store.snapshot()==before,"Accepting a favor transferred inventory")
 check(not domain.choose(first.token,"charcoal","accept").accepted,"Repeated acceptance changed the receipt")
 if store.count("player","charcoal")>0: store.pay("player",{"charcoal":store.count("player","charcoal")})
 before=store.snapshot()
 check(not domain.choose(first.token,"charcoal","deliver").accepted and store.snapshot()==before,"Missing favor goods paid a reward")
 store.receive("player","charcoal",2)
 var money:=store.count("player","coin"); var purse:=store.count(merchant_id,"coin"); var stock:=store.count(merchant_id,"charcoal")
 var observer:=func(fact: Dictionary):
  if fact.kind=="trade_committed" and fact.source=="player":
   check(domain.favor_state(merchant_id,"charcoal")=="completed" and relations.disposition(merchant_id,"player")==10,"Inventory observers saw a half-committed favor/relationship")
 game.session.facts.committed.connect(observer)
 check(domain.choose(first.token,"charcoal","deliver").accepted,"Funded real favor exchange refused")
 game.session.facts.committed.disconnect(observer)
 check(store.count("player","coin")==money+8 and store.count(merchant_id,"coin")==purse-8 and store.count("player","charcoal")==0 and store.count(merchant_id,"charcoal")==stock+2,"Favor failed conservation of goods and money")
 before=store.snapshot()
 check(not domain.choose(first.token,"charcoal","deliver").accepted and store.snapshot()==before and relations.disposition(merchant_id,"player")==10,"Completed favor could pay or give trust again")
 var uid:=store.find_owned(merchant_id,"river_sabre")
 check(game.town_services.price(uid,true)==15 and game.town_services.price(uid,false)==8,"Personal trust failed actual bounded shop price")
 # Request/accept and full inventory failure must leave the whole social/inventory state intact.
 game.player.position=aida.position+Vector2(0,35)
 var aida_handle:=domain.begin("river.aida")
 check(aida_handle.accepted and not domain.choose(first.token,"supply").accepted,"A new speaker did not retire the previous handle")
 check(not domain.choose(aida_handle.token,"archives").accepted,"Locked trust topic leaked its contents")
 check(not domain.choose(aida_handle.token,"analysis").accepted,"Dialogue ignored its actual attribute requirement")
 var insight:=Buff.new(); insight.status_id="test.npc.insight"; insight.duration=1; insight.stat_modifiers={"intelligence":2}
 game.player.get_node("BuffManager").apply_buff(insight,game.player)
 check(domain.choose(aida_handle.token,"analysis").accepted,"Effective attribute failed a qualified dialogue insight")
 game.player.get_node("BuffManager").tick(1.1)
 check(not domain.choose(aida_handle.token,"analysis").accepted,"Expired attributes remained eligible for a dialogue request")
 check(domain.choose(aida_handle.token,"herbs","accept").accepted,"Aida favor could not be accepted")
 store.receive("player","herb",2)
 var herb:=store.count("river.aida","herb"); var coins:=store.count("player","coin")
 store.pay("river.aida",{"coin":store.count("river.aida","coin")})
 before=store.snapshot()
 check(not domain.choose(aida_handle.token,"herbs","deliver").accepted and store.snapshot()==before,"NPC with no real purse created money")
 store.receive("river.aida","coin",24)
 store.receive_into("river.aida.pocket","river_shield",1000); store.receive_into("river.aida.pack","river_shield",1000)
 before=store.snapshot(); var memory:=domain.snapshot()
 check(not domain.choose(aida_handle.token,"herbs","deliver").accepted and store.snapshot()==before and domain.snapshot()==memory,"Full NPC inventory lost goods, paid money or completed the favor")
 store.pay("river.aida",{"river_shield":store.count("river.aida","river_shield")})
 check(domain.choose(aida_handle.token,"herbs","deliver").accepted and store.count("player","coin")==coins+6 and store.count("river.aida","herb")==herb+2,"Real Aida delivery failed after capacity recovered")
 known=game.progress.visited.duplicate(); claims=game.progress.claims.duplicate()
 check(domain.choose(aida_handle.token,"archives").accepted and game.progress.visited==known and game.progress.claims==claims,"Trusted rumor did not unlock or remotely explored the archive")
 check(not domain.choose(aida_handle.token,"bridge_deed").accepted,"World-deed acknowledgment was available without the deed")
 game.progress.claims["river.bridge_fixed"]=true
 check(domain.choose(aida_handle.token,"bridge_deed").accepted and relations.disposition("river.aida","player")==20,"Actual world deed gave no personal recognition")
 check(domain.choose(aida_handle.token,"bridge_deed").accepted and relations.disposition("river.aida","player")==20,"Repeated deed discussion farmed trust")
 # Off-duty chat remains possible; service and favor mutation still recheck the live schedule.
 aida.hour_query=func(): return 23.0
 check(domain.choose(aida_handle.token,"about").accepted and not domain.choose(aida_handle.token,"quests").accepted,"Off-duty routine blocked all chat or offered services")
 aida.hour_query=game.session.hour_query
 var wall:=StaticBody2D.new(); wall.collision_layer=1; wall.collision_mask=0
 var collider:=CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=Vector2(60,4); collider.shape=shape; wall.add_child(collider)
 wall.position=aida.position+Vector2(0,17); game.region_root.add_child(wall)
 await physics_frame; await process_frame
 check(not domain.choose(aida_handle.token,"about").accepted,"Conversation reached an NPC through a real wall")
 wall.queue_free(); await physics_frame; await process_frame
 var stale: int=aida_handle.token
 game.player.position+=Vector2(200,0)
 check(not domain.choose(stale,"about").accepted,"Stale conversation worked from a distance")
 game.player.position=aida.position+Vector2(0,35)
 var saved:=domain.snapshot(); var dispositions: Dictionary=relations.snapshot().dispositions
 game._save_progress(); await fixture.close()
 fixture=Fixture.new(self); game=await fixture.boot(true,true)
 domain=game.session.conversations; store=game.session.inventory; relations=game.session.relations
 check(domain.snapshot()==saved and relations.snapshot().dispositions==dispositions and not domain.choose(stale,"about").accepted,"Real save/re-entry lost social memory or restored a transient handle")
 check(store.count(merchant_id,"charcoal")==stock+2 and store.count("river.aida","herb")==herb+2,"NPC stock was refilled or forgot the delivered goods")
 var corrupt:=saved.duplicate(true); corrupt.favors["river.aida/unknown"]="completed"
 check(not NpcConversationService.valid_state(corrupt) and not domain.restore(corrupt) and domain.snapshot()==saved,"Invalid social restore changed current memory")
 corrupt=saved.duplicate(true); corrupt.known[merchant_id].append("supply")
 check(not NpcConversationService.valid_state(corrupt),"Duplicate topic memory accepted")
 check(not RelationService.valid_dispositions({"a|b":INF}),"Nonfinite disposition accepted")
 # Attack and death enter shared hostility/loot rules, not invulnerable service markers.
 merchant=game.session.actor_for_id(merchant_id) as ServiceNPC
 game.player.position=merchant.position+Vector2(-35,0)
 var handle:=domain.begin(merchant_id)
 CombatExecutor.report_hit(game.player,merchant,2,merchant.position,null,["physical","melee"],"npc.attack.test")
 check(relations.attitude(merchant_id,"player")=="hostile" and relations.disposition(merchant_id,"player")==-20 and not domain.choose(handle.token,"trade").accepted,"Hostile contact left services available or did not record betrayal")
 check(not game.town_services.transact(store.find_owned(merchant_id,"river_sabre"),false).accepted,"Counter bypassed hostile merchant")
 merchant.health_component.tick(.6)
 CombatExecutor.report_hit(game.player,merchant,10000,merchant.position,null,["physical","melee"],"npc.death.test")
 await process_frame
 check(game.session.actor_records[merchant_id].dead and game.progress.loot_records.has(merchant_id),"Service NPC death produced no persistent real corpse")
 var remaining:=store.count(merchant_id,"coin")
 game._save_progress(); await fixture.close()
 fixture=Fixture.new(self); game=await fixture.boot(true,true)
 check(game.session.actor_for_id(merchant_id)==null and game.session.actor_records[merchant_id].dead and not game.town_services.reason().is_empty(),"Dead merchant respawned or counter still served")
 check(game.session.inventory.count(merchant_id,"coin")==remaining,"Reload minted dead merchant money")
 await fixture.close()
 if failures.is_empty(): print("PASS NPC domain: live residents, remembered rumors, no remote discovery, funded favor conservation/rollback/once-only, trust prices/deeds, schedule/distance/hostility, actual save re-entry, validated social restore and persistent death/loot")
 quit(0 if failures.is_empty() else 1)
