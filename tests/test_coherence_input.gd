extends "res://tests/support/input_scene_probe.gd"
## Controlled condition/content fixtures; normal AI, world and real keyboard/mouse.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
const Residents=preload("res://tests/support/resident_service_fixture.gd")
var intervals: Array[float]=[]
var peak_nodes := 0
var peak_process_ms := 0.0
func _process(delta: float) -> bool:
 if is_instance_valid(game) and game.ready_for_play:
  if intervals.size()<20000: intervals.append(delta*1000)
  peak_nodes=maxi(peak_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
  peak_process_ms=maxf(peak_process_ms,Performance.get_monitor(Performance.TIME_PROCESS)*1000)
 return false
func run() -> void:
 root.size=Vector2i(1152,648)
 var fixture:=Fixture.new(self); game=await fixture.boot(true)
 GameRuntime.instance.set_process(true)
 for foe in game.active_enemies: foe.process_mode=Node.PROCESS_MODE_INHERIT
 var extension:=Residents.new(); extension.install(game)
 var actor:=game.player; var store:=game.session.inventory
 actor.position=Vector2(-4300,700); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 var needs:=actor.actor_context.actions.needs; needs.hydration=10; needs.fatigue=90
 ActorProgression.refresh_stamina(actor)
 await key(KEY_P,true); await key(KEY_P,false); await click("属性与派生")
 var screen: CharacterProgressionScreen
 for node in game.ui.modal.find_children("*","VBoxContainer",true,false):
  if node is CharacterProgressionScreen: screen=node; break
 check(screen!=null and screen._overview.text.contains("当前回复 1.8/秒") and screen._overview.text.contains("基础10.0"),"P did not show actual dehydration/fatigue recovery separately from base")
 if not screen: quit(1); return
 var endurance: Button=screen._attribute_buttons.endurance
 var branch: Button=screen._branch_buttons[SkillMastery.School.MELEE]
 var identity:=endurance.get_instance_id(); var branch_id:=branch.get_instance_id()
 endurance.grab_focus()
 CombatExecutor.report_exp_bonus(actor,100)
 await frames(35)
 check(is_instance_valid(endurance) and screen._attribute_buttons.endurance.get_instance_id()==identity and screen._branch_buttons[SkillMastery.School.MELEE].get_instance_id()==branch_id and endurance.has_focus(),"Live experience rebuilt controls or discarded keyboard focus")
 await click("耐力 +1")
 check(actor.stats_component.endurance==11 and actor.actor_context.actions.stamina.maximum==102,"Stable attribute control did not submit a real investment")
 await capture("effective-stamina-stable-controls")
 needs.hydration=100; needs.fatigue=0; ActorProgression.refresh_stamina(actor); await frames(24)
 check(screen._overview.text.contains("当前回复 10.2/秒"),"Recovery summary failed to update in place after needs changed")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 # Separate merchant resources and money, through the same actual conversation UI.
 store.receive("player","coin",30)
 var merchant:=game.session.actor_for_id(Residents.MERCHANT) as ServiceNPC
 actor.position=merchant.position+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 var primary_money:=store.count(TownServices.MERCHANT,"coin")
 await key(KEY_F,true); await key(KEY_F,false); await click("查看行商货物"); await click("购买实物")
 await click(store.definitions.arrow.display_name+" ×6 · 2币"); await click("购买一件 · 2币")
 check(store.count(Residents.MERCHANT,"arrow")==5 and store.count(Residents.MERCHANT,"coin")==32 and store.count(TownServices.MERCHANT,"coin")==primary_money,"Second merchant UI used another merchant's purse/stock")
 await capture("independent-merchant")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 var trainer:=game.session.actor_for_id(Residents.TRAINER) as ServiceNPC
 actor.position=trainer.position+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 var teacher_money:=store.count(game.town_services.training.actor_id,"coin")
 await key(KEY_F,true); await key(KEY_F,false); await click("学习旅人课程"); await click("破势斩 · 8币")
 check(actor.actor_context.martial.learned.has("blade_breaker") and store.count(Residents.TRAINER,"coin")==8 and store.count(game.town_services.training.actor_id,"coin")==teacher_money,"Actual independent course charged the original teacher")
 await capture("independent-training")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 var aida:=game.session.actor_for_id("river.aida") as ServiceNPC
 actor.position=aida.position+Vector2(0,35); actor.get_node("Camera2D").reset_smoothing(); await frames(8)
 await key(KEY_F,true); await key(KEY_F,false); await click("北路和东路各有什么？")
 await capture("typed-route-leads")
 await click("委托：留一份药草储备"); await click("接受委托")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false); await key(KEY_J,true); await key(KEY_J,false)
 await click("委托：留一份药草储备"); await click("追踪这个人情")
 var tracked:="npc.favor.river.aida/herbs"
 check(game.progress.tracked_quest==tracked and not game.guidance.tracked().is_empty(),"Real J tracking did not use the persistent shared objective slot")
 root.size=Vector2i(960,600); await frames(6); await capture("personal-objective-small")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
 store.receive("player","herb",2); await frames(10)
 check(game.guidance.tracked().title.contains("交付"),"Actual acquired goods did not update the shared next step")
 await key(KEY_F,true); await key(KEY_F,false); await click("委托：留一份药草储备"); await click("交付物资并领取报酬")
 check(game.session.conversations.favor_state("river.aida","herbs")=="completed" and game.guidance.tracked().is_empty(),"Completed delivery remained an actionable shared objective")
 await capture("personal-delivery")
 await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false); await key(KEY_F5,true); await key(KEY_F5,false)
 var saved:=game.session.conversations.snapshot()
 await fixture.close(); fixture=Fixture.new(self); game=await fixture.boot(true)
 check(game.session.conversations.snapshot()==saved and game.progress.tracked_quest==tracked and game.session.inventory.count(Residents.TRAINER,"coin")==8 and game.session.inventory.count(Residents.MERCHANT,"coin")==32,"Real save/re-entry lost independently owned service results or personal objective history")
 await fixture.close(); extension.release()
 intervals.sort()
 if not intervals.is_empty(): print("COHERENCE_FRAME_SAMPLE "+JSON.stringify({"platform":DisplayServer.get_name(),"frames":intervals.size(),"interval_p50_ms":intervals[int(intervals.size()*.5)],"interval_p95_ms":intervals[mini(intervals.size()-1,int(intervals.size()*.95))],"maximum_interval_ms":intervals[-1],"peak_nodes":peak_nodes,"peak_process_ms":peak_process_ms,"scope":"software/cloud input fixture, not target-device or two-hour performance"}))
 if failures.is_empty(): print("PASS coherence input: real P effective recovery and stable focus under XP, two independent service owners/purses, typed leads, shared J tracking, actual delivery and save/re-entry; controlled authored content/needs/stock/position with normal world/AI")
 quit(0 if failures.is_empty() else 1)
