extends "res://tests/support/input_scene_probe.gd"
## Controlled route fixture: actual UI requests/transactions, fixed travel and quiet AI.
const Fixture=preload("res://tests/support/grayriver_fixture.gd")
func read_record(id: String) -> void:
 game.ui.close_modal()
 for entry in game.current_data.discoveries:
  if entry.id==id:
   game.player.position=entry.pos
   check(game.progress_service.discover(entry),"Authored discovery refused: "+id)
   return
 check(false,"Missing discovery: "+id)
func talk(id: String) -> void:
 game.ui.close_modal()
 var npc:=game.session.actor_for_id(id) as ServiceNPC
 check(npc!=null,"Missing real NPC: "+id)
 if not npc:return
 npc.set_physics_process(false)
 game.player.position=npc.position+Vector2(0,35)
 game.residents.open(id)
 await frames()
func favor(id: String,topic: String) -> void:
 await talk(id)
 await click_identity({"ui_action":"npc_topic","actor_id":id,"topic":topic})
 await click("接受委托")
 await click("交付物资并领取报酬")
func row(id: String) -> Dictionary:
 for entry in game.guidance.journey.rows():
  if entry.id==id:return entry
 return {}
func run() -> void:
 root.size=Vector2i(1152,648)
 var fixture:=Fixture.new(self);game=await fixture.boot(true)
 var store:=game.session.inventory
 var before:=store.snapshot();var progress:=game.progress.serialize_save_data()
 for i in range(10):game.guidance.journey.rows();game.guidance.journey.town_goal()
 check(store.snapshot()==before and game.progress.serialize_save_data()==progress,"Reading guide changed inventory/progress")
 check(not game.player.actor_context.magic.awakened and not row("pack").done,"Fresh journey already prepared/awakened")
 await key(KEY_TAB,true);await key(KEY_TAB,false)
 await click("首次远征 · 整备与成长")
 await capture("first-loop-checklist")
 read_record("river.handbook");read_record("river.pack");read_record("river.material.cloth_bundle.v1")
 var sword:=store.find_owned("player","river_sabre")
 check(store.equip("player",sword).accepted and row("weapon").done and row("cloth").done,"Real starter preparation did not update guide")
 game.ui.close_modal();game.hub.open_journey();await frames()
 var profile:=game.session.conversations.catalog.profile("river.innkeeper")
 await click(profile.character.title+" · "+profile.topic("grain_errand").title+"（可咨询）")
 check(game.progress.waypoint.get("region","")=="camp","Inn navigation attempted to mark unreachable interior coordinates from outside")
 game.ui.close_modal();root.size=Vector2i(960,600);game.hub.open_journey();await frames()
 await capture("first-loop-small-window")
 await click("追踪首次出征")
 root.size=Vector2i(1152,648);await frames()
 check(game.progress.tracked_quest==FirstExpeditionGuide.QUEST and game.progress.waypoint.is_empty(),"Tracking revealed unexplored coordinates or selected wrong quest")
 # Alternate honest funding: two finite NPC purses, using only authored starter goods.
 var herb:=store.count("player","herb");var aida_money:=store.count("river.aida","coin")
 await favor("river.aida","herbs")
 check(store.count("player","coin")==6 and store.count("player","herb")==herb-2 and store.count("river.aida","coin")==aida_money-6,"Herb favor did not conserve starting materials/payment")
 await fixture.travel("river_inn")
 var grain:=store.count("player","grain");var inn_money:=store.count("river.innkeeper","coin")
 await favor("river.innkeeper","grain_errand")
 check(store.count("player","coin")==8 and store.count("player","grain")==grain-1 and store.count("river.innkeeper","coin")==inn_money-2,"New inn errand did not transfer actual grain/coins")
 var handle:=game.session.conversations.begin("river.innkeeper")
 before=store.snapshot()
 check(not game.session.conversations.choose(handle.token,"grain_errand","deliver").accepted and store.snapshot()==before,"Errand paid twice")
 await fixture.travel("camp")
 var trainer:=game.town_services.training.actor_id
 var teacher_money:=store.count(trainer,"coin")
 await talk(trainer)
 await click_identity({"ui_action":"npc_topic","actor_id":trainer,"topic":"training"})
 await click_identity({"ui_action":"learn_technique","actor_id":trainer,"course_id":"blade_breaker"})
 check(row("training").done and store.count("player","coin")==0 and store.count(trainer,"coin")==teacher_money+8,"Real course did not teach or conserve tuition")
 check(game.player.mana_component.max_mp==0 and game.player.actor_context.martial.route_choices().size()>0,"Warrior training granted magic or no usable routes")
 game.ui.close_modal();game.player.position=Vector2(-4000,800)
 var actions:=game.player.actor_context.actions
 actions.cancel()
 for heavy in [false,true]:
  var request:=Action.melee(game.player);request.direction=Vector2.RIGHT
  if heavy:request.action_type=Action.ActionType.HEAVY_ATTACK
  check(actions.try_action(request).accepted,"Newly trained ordinary actor could not perform sequence")
  if heavy:actions.advance(actions.profile.windup+.01)
  actions.advance(actions.remaining)
 var art:=actions.capture_weapon_art(Vector2.RIGHT)
 var stamina:=actions.stamina.current
 check(actions.try_action(art).accepted and actions.stamina.current<stamina and game.player.mana_component.mp==0,"Learned ordinary combo art did not spend stamina without MP")
 actions.cancel()
 game.player.position=Vector2(-3100,1835)
 game.workshop.show_crafts();await frames()
 var charcoal:=store.count("player","charcoal");var ash:=store.count("player","ash")
 await click(game.player.skill_manager.combinations.supplies.title("ash"))
 await click("加工："+game.player.skill_manager.combinations.supplies.title("ash"))
 check(store.count("player","charcoal")==charcoal-1 and store.count("player","ash")==ash+1,"Workbench did not use real retained starter materials")
 read_record("river.fire")
 await fixture.travel("river_archive")
 # Controlled separation from combat: move foes, do not grant claims or rewards.
 for enemy in game.active_enemies:enemy.position=Vector2(10000,10000)
 read_record("river.dossier")
 var press: SpellWorldObject
 for node in game.region_root.get_children():
  if node is SpellWorldObject and node.spec.id=="archive.index_press":press=node
 check(press!=null,"Missing actual manual mechanism")
 if press:
  game.ui.close_modal();game.player.position=press.position-Vector2(40,0)
  await key(KEY_F,true);await key(KEY_F,false)
  await key(KEY_F,true);await key(KEY_F,false)
  game.player.field_work.tick(5)
  check(game.progress.claims.has("archive.index_press"),"Manual action did not complete expedition evidence")
 await fixture.travel("camp")
 game.player.position=Vector2(-2900,2200)
 var quest:=game.guidance.journey.quest();var points:=game.player.stats_component.attribute_points
 check(game.progress_service.claim_quest(quest),"Real ordinary quest could not be reported")
 check(game.player.stats_component.attribute_points==points+1 and not game.progress_service.claim_quest(quest),"Report duplicated or lost earned growth")
 check(row("report").done and game.guidance.journey.town_goal().get("journey",false),"Report did not surface remaining growth")
 check(game.progress.journal.any(func(entry):return entry.id=="quest."+FirstExpeditionGuide.QUEST and "下一条委托" in entry.text),"Next-step guidance absent from persistent report")
 game.ui.close_modal();await key(KEY_P,true);await key(KEY_P,false)
 await click("属性与派生");await click("耐力 +1")
 check(game.player.stats_component.attribute_points==points and game.player.stats_component.endurance==11,"Earned report point was not spent through actual growth UI")
 game.ui.close_modal()
 var saved:=store.snapshot_owners(["player",trainer,"river.innkeeper","river.aida"])
 game._save_progress();await fixture.close()
 game=await fixture.boot(true)
 check(game.session.inventory.snapshot_owners(["player",trainer,"river.innkeeper","river.aida"])==saved,"Cold reentry refilled course/errand/craft inventory")
 check(row("training").done and row("report").done and game.player.stats_component.endurance==11 and game.player.mana_component.max_mp==0,"Cold reentry lost ordinary growth/knowledge or granted magic")
 check(game.session.conversations.favor_state("river.innkeeper","grain_errand")=="completed","New errand completion not preserved")
 await fixture.close()
 if failures.is_empty():print("PASS first expedition loop: pure guide, real finite errands/tuition, retained-material craft, manual evidence, report/point input and cold reentry; controlled navigation/AI")
 quit(0 if failures.is_empty() else 1)
