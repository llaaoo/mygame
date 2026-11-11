class_name FirstExpeditionGuide
extends RefCounted
## Read-only journey projection: inventory, knowledge, quests and NPCs stay authoritative.
const QUEST := "river.first_expedition"
var game: GrayriverGame
func _init(owner_game: GrayriverGame) -> void: game=owner_game

func fact_goal(id: String,title: String) -> Dictionary:
 var goal:=game.guidance.prerequisite_objective(id)
 goal.title=title
 return goal

func npc_goal(id: String,title: String) -> Dictionary:
 var profile:=game.session.conversations.catalog.profile(id)
 if not profile: return {}
 var actor:=game.session.actor_for_id(id)
 if game.session.actor_records.get(id,{}).get("dead",false) or is_instance_valid(actor) and actor.get_node("HealthComponent").is_dead:
  return {"title":profile.character.title+"已死亡，原服务不可用","region":profile.region_id,"position":profile.work_location(),"known":false,"terminal":true}
 var point: Vector2=actor.position if is_instance_valid(actor) else profile.work_location()
 return {"title":title,"region":profile.region_id,"position":point,"known":true}

func quest() -> ExplorationQuestData:
 for entry in game.quests:
  if entry.id==QUEST: return entry
 return null

func rows() -> Array[Dictionary]:
 var store:=game.session.inventory
 var progress:=game.progress
 var reported:=progress.claims.has("quest."+QUEST)
 var armed:=has_weapon()
 var food:=0
 for id in ["ration","broth"]: food+=store.count("player",id)
 var water:=store.count("player","clean_water")
 var cloth:=store.count("player","cloth")
 var learned:=game.player.actor_context.martial.learned.has("blade_breaker")
 var offer:=game.town_services.training.offer("blade_breaker")
 var coins:=store.count("player","coin")
 var course_reason:=TechniqueLearning.reason(offer,game.player.actor_context)
 var health:=game.player.health_component
 var needs:=game.survival.needs
 var quest_data:=quest()
 var complete: bool=quest_data!=null and quest_data.is_complete(progress)
 var result: Array[Dictionary]=[
  {"id":"handbook","title":"了解这趟远征","done":progress.claims.has("river.handbook"),"detail":"手册记录北路、手工压印和返程。未觉醒也可完成；首次调查会学到真实配方。","goal":fact_goal("river.handbook","读行路手册")},
  {"id":"pack","title":"领取一次性离镇补给","done":progress.claims.has("river.pack"),"detail":"回收短刀、口粮与水只领一次，返镇不会补满。","goal":fact_goal("river.pack","领取离镇口粮旧械包")},
  {"id":"weapon","title":"穿戴主手武器","done":armed,"detail":InputBindings.menu_help("O打开穿戴。左键短按轻击、长按重击；右键格挡，别把体力全部花在进攻。工具小刀不是战斗武器。"),"action":"equipment"},
  {"id":"provisions","title":"检查可携补给","done":food>0 and water>0,"detail":"实有餐食%d份、清水%d份。N使用或放入口袋，K绑定快捷键；需要安全处站定使用。放下的背包不算可用补给。"%[food,water],"action":"supplies"},
  {"id":"cloth","title":"留出手工检修材料","done":progress.claims.has("archive.index_press") or cloth>0,"detail":"现有布料%d。压印台需布料1，不需要法力；做抹布或出售前留一份。附近旅人布料包用完不补。"%cloth,"goal":fact_goal("river.material.cloth_bundle.v1","领取布料，留1份检修")},
  {"id":"training","title":"可选：向训练师学习破势斩","done":learned,"optional":true,"detail":("已学会。K查看连招：轻→重后，在窗口内Ctrl+左键手动接招；不花MP，不占快捷槽。" if learned else "课程8币，现有%d币。%s。萨芙收炭屑2付8币；也可交艾妲草药2得6币、交客栈苇娘谷物1得2币。都是有限的实物交换，留好自己需要的材料；课程不是出发条件。"%[coins,course_reason if not course_reason.is_empty() else "已满足学习条件，当值时当面购买"]),"goal":npc_goal(game.town_services.training.actor_id,"找当值训练师学习武技（可选）"),"action":"techniques","links":funding_links() if not learned and coins<8 else []},
  {"id":"expedition","title":"北路调查与手工修复","done":complete,"detail":"从西侧读猎营记录，在安全空地整备再接敌。档案窖可随时撤回，借书架分开应对；受伤先撤退补给，不必连续打完所有敌人。东侧压印台用布料1检修，再取名册。","goal":game.guidance.next_step(quest_data) if quest_data else {}},
  {"id":"report","title":"带成果返镇报告","done":reported,"detail":"取得记录不等于交付；回镇报告首次出征，获得原有1属性点，不要求觉醒。","goal":npc_goal("river.aida","返镇向艾妲报告")},
  {"id":"growth","title":"把成果变成下一程能力","done":reported and game.player.stats_component.attribute_points==0 and game.player.mastery_manager.get_available_perk_points()==0,"detail":InputBindings.menu_help("现有%d属性点、%dPerk点。P查看实际加点效果与前置；学会的武技仍需K核对连招配置。没有点数也可通过训练和装备成长。"%[game.player.stats_component.attribute_points,game.player.mastery_manager.get_available_perk_points()]),"action":"progression"},
  {"id":"return","title":"处理实物，再准备下一程","done":false,"optional":true,"detail":"先保留趁手武器和合适防具，多余装备到萨芙处比较出售、拆解或强化；报价和空间以现场为准。制作或购买食水补充真实消耗，客床休息按小时耗粮水；不必觉醒也可继续探索。","goal":npc_goal(TownServices.MERCHANT,"找萨芙处理多余战利品"),"action":"supplies"}
 ]
 # Current readiness is deliberately not a permanent tutorial completion flag.
 result.push_front({"id":"recovery","title":"先安全恢复，再接敌","done":health.hp>=health.max_hp*.65 and needs.fatigue<60 and needs.nutrition>20 and needs.hydration>20,"detail":"生命%d/%d，疲劳%.0f。吃喝、休息与撤退都需实际操作；休息会结算时间和补给，菜单不暂停危险。"%[health.hp,health.max_hp,needs.fatigue],"goal":{"title":"到镇中篝火整休，检查粮水","region":"camp","position":Vector2(-3500,2100),"known":true},"action":"supplies"})
 return result

func town_goal() -> Dictionary:
 if not game.is_at_base() or not game.progress.waypoint.is_empty(): return {}
 if game.progress.tracked_quest not in ["",QUEST]: return {}
 var store:=game.session.inventory
 var progress:=game.progress
 var health:=game.player.health_component
 var needs:=game.survival.needs
 var goal: Dictionary={}
 if health.hp<health.max_hp*.65 or needs.fatigue>=60 or needs.nutrition<=20 or needs.hydration<=20:
  goal={"title":"先检查食水与伤势，再出发","region":"camp","position":Vector2(-3500,2100),"known":true}
 else:
  for id in ["river.handbook","river.pack"]:
   if not progress.claims.has(id):
    goal=fact_goal(id,"读行路手册" if id=="river.handbook" else "领取离镇口粮旧械包")
    break
 if goal.is_empty() and not has_weapon():
  goal={"title":InputBindings.menu_help("O穿戴主手武器，再出发"),"region":"","known":true,"navigate":false}
 if goal.is_empty() and (store.count("player","ration")+store.count("player","broth")==0 or store.count("player","clean_water")==0):
  goal={"title":InputBindings.menu_help("N检查可携食水，Tab查看补给途径"),"region":"","known":true,"navigate":false}
 if goal.is_empty() and not progress.claims.has("archive.index_press") and store.count("player","cloth")==0 and not progress.claims.has("river.material.cloth_bundle.v1"):
  goal=fact_goal("river.material.cloth_bundle.v1","领取布料，留1份检修")
 if goal.is_empty() and progress.claims.has("quest."+QUEST) and (game.player.stats_component.attribute_points>0 or game.player.mastery_manager.get_available_perk_points()>0):
  goal={"title":InputBindings.menu_help("远征已交付：P分配已有成长点数"),"region":"","known":true,"navigate":false}
 if not goal.is_empty():goal["journey"]=true
 return goal

func has_weapon() -> bool:
 var store:=game.session.inventory
 var uid: String=str(store.equipped("player").get(str(EquipmentData.SlotType.RIGHT_HAND),""))
 var item:=store.item(uid)
 var data:=store.definitions.get(item.definition_id) as EquipmentData if item else null
 return data!=null and (data.attack_profile!=null or data.moveset!=null)

func funding_links() -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for pair in [[TownServices.MERCHANT,"charcoal"],["river.aida","herbs"],["river.innkeeper","grain_errand"]]:
  var profile:=game.session.conversations.catalog.profile(pair[0])
  var topic:=profile.topic(pair[1]) if profile else null
  if not topic: continue
  var state:=game.session.conversations.favor_state(pair[0],pair[1])
  var status: String="已结清" if state=="completed" else "已接受" if state=="accepted" else "可咨询"
  result.append({"actor":pair[0],"title":profile.character.title+" · "+topic.title+"（"+status+"）","goal":npc_goal(pair[0],profile.character.title+" · "+topic.title)})
 return result
