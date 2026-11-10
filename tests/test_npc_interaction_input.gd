extends "res://tests/support/input_scene_probe.gd"
## Normal AI/world; controlled stocks and locations, every conversation uses real input.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
var attacks := 0
func run() -> void:
 root.size=Vector2i(1152,648)
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 GameRuntime.instance.set_process(true)
 for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
 var actor:=game.player; var store:=game.session.inventory; var domain:=game.session.conversations
 game.session.facts.committed.connect(func(fact: Dictionary):
  if fact.source=="player" and fact.kind=="physical_action_started": attacks+=1)
 var merchant:=game.session.actor_for_id(TownServices.MERCHANT) as ServiceNPC
 actor.position=merchant.position+Vector2(-35,0); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 await key(KEY_F,true); await key(KEY_F,false)
 check(is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("npc_conversation","")==TownServices.MERCHANT,"F did not talk to an actual town resident")
 var clock:=store.clock_seconds; await frames(20)
 check(store.clock_seconds>clock and not paused,"Conversation paused the world")
 var visited:=game.progress.visited.duplicate()
 await click("你的货从哪里来？")
 check(domain.seen(TownServices.MERCHANT,"supply") and game.progress.visited==visited,"Mouse conversation failed topic memory or fabricated exploration")
 await capture("merchant-topics")
 store.receive("player","charcoal",2)
 var charcoal:=store.count("player","charcoal"); var money:=store.count("player","coin")
 await click("委托：补一批木炭"); await click("接受委托")
 check(domain.favor_state(TownServices.MERCHANT,"charcoal")=="accepted" and store.count("player","charcoal")==charcoal,"Actual favor acceptance did not retain resources")
 await click("交付物资并领取报酬")
 check(domain.favor_state(TownServices.MERCHANT,"charcoal")=="completed" and store.count("player","charcoal")==charcoal-2 and store.count("player","coin")==money+8,"Mouse delivery did not conserve real goods/payment")
 await capture("merchant-favor-completed")
 await click("交易与整修"); await click("购买实物")
 check(game.town_services.price(store.find_owned(TownServices.MERCHANT,"river_sabre"),true)==15,"Real dialogue service lost the familiar price")
 await capture("familiar-shop")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 await key(KEY_J,true); await key(KEY_J,false)
 check(game.hub.entries().any(func(entry): return entry.get("npc_favor",false) and entry.done)==false,"Default active quest filter included completed favors")
 # Completed favor remains available in journal knowledge, no remote reward button.
 await click("进行中");
 for i in range(3): await key(KEY_DOWN,true); await key(KEY_DOWN,false)
 await key(KEY_ENTER,true); await key(KEY_ENTER,false)
 check(game.hub.entries().any(func(entry): return entry.get("npc_favor",false) and entry.done),"J did not expose personal favor history")
 await click("委托：补一批木炭")
 await capture("favor-journal")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 var aida:=game.session.actor_for_id("river.aida") as ServiceNPC
 actor.position=aida.position+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 await key(KEY_F,true); await key(KEY_F,false)
 check(game.ui.modal.get_meta("npc_conversation","")=="river.aida","F selected the board instead of the nearby actual NPC")
 await click("能告诉我更远的档案线索吗？")
 check(not domain.seen("river.aida","archives"),"Locked mouse topic leaked trusted knowledge")
 await click("北路和东路各有什么？")
 root.size=Vector2i(960,600); await frames(6)
 await capture("aida-routes-small")
 # Mutate controlled clock while menu stays open: real-time service availability must update.
 aida.hour_query=func(): return 23.0
 await frames(30)
 await click("查看河谷委托")
 check(is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("npc_conversation","")=="river.aida","Off-duty conversation opened a service")
 await capture("off-duty-service")
 aida.hour_query=game.session.hour_query
 await click("结束交谈")
 check(not actor.ui_blocked,"End conversation left player input blocked")
 # Trainer remains a shared service, reached through conversation and original learning transaction.
 var trainer:=game.session.actor_for_id(game.town_services.training.actor_id) as ServiceNPC
 actor.position=trainer.position+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 await key(KEY_F,true); await key(KEY_F,false); await click("学习武技与野外技艺")
 check(is_instance_valid(game.ui.modal) and game.ui.modal.get_meta("npc_conversation","").is_empty(),"Trainer conversation did not open existing paid courses")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 actor.position=merchant.position+Vector2(-35,0); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 await key(KEY_F,true); await key(KEY_F,false)
 actor.position+=Vector2(-200,0); await frames(30)
 check(not actor.ui_blocked,"Out-of-range conversation retained its active UI")
 check(attacks==0,"Conversation clicks leaked attacks into the world")
 await key(KEY_F5,true); await key(KEY_F5,false)
 var saved:=domain.snapshot(); var disposition:=game.session.relations.disposition(TownServices.MERCHANT,"player")
 await fixture.close(); fixture=Fixture.new(self); game=await fixture.boot(true)
 check(game.session.conversations.snapshot()==saved and game.session.relations.disposition(TownServices.MERCHANT,"player")==disposition,"Actual scene re-entry forgot conversations/favor/trust")
 await fixture.close()
 if failures.is_empty(): print("PASS NPC input: actual F residents, live conversation, rumors, accept/deliver finite favor, familiar shop, J history, locked topic, small-window scroll, off-duty refusal, trainer route, distance cancellation, no attack leakage and save/re-entry; controlled stock/clock/location")
 quit(0 if failures.is_empty() else 1)
