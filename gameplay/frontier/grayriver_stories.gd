class_name GrayriverStories
extends RefCounted
## Named people retain their actual stock; diplomacy never awards their equipment.
const PEOPLE := {
 "river.enemy.camp.bridge_keeper":{"key":"bridge","claim":"river.bridge_settled","title":"处理断桥守望者的拦路","region":"camp","position":Vector2(-1700,650)},
 "river.enemy.river_mine.quartermaster":{"key":"mine","claim":"river.mine_settled","title":"处理运料官的欠货","region":"river_mine","position":Vector2(420,-220)},
 "river.enemy.river_prison.veteran":{"key":"veteran","claim":"river.veteran_settled","title":"结束老兵的守岗","region":"river_prison","position":Vector2(80,-450)}}
var game: GrayriverGame
var actors: Dictionary = {}
func _init(owner_game: GrayriverGame) -> void: game=owner_game
func objective(id: String) -> Dictionary:
 for person: Dictionary in PEOPLE.values():
  if person.claim==id:
   return {"title":person.title,"region":person.region,"position":person.position,"known":game.guidance.known(person.region,person.position)}
 return {}
func mount(enemy: Enemy) -> void:
 var id:=str(enemy.get_meta("frontier_claim",""))
 if not PEOPLE.has(id) or game.practice_active or game.progress.choices.get("river.rehearsal","")=="yes": return
 actors[id]=enemy
 var state: Dictionary=game.progress.story_actors.get(id,{})
 if not game.session.actor_records.has(id): enemy.story_truce=state.get("attitude","watching")!="hostile"
 enemy.set_meta("story_loot_eligible",true)
 if state.has("materials") and not enemy.actor_context.restored_inventory:
  enemy.skill_manager.combinations.supplies.amounts=state.materials.duplicate()
  enemy.health_component.hp=clampi(int(state.hp),1,enemy.health_component.max_hp)
 if game.progress.claims.has(PEOPLE[id].claim):
  enemy.rewards_enabled=false
  if enemy.story_truce: game.active_enemies.erase(enemy)
 enemy.actor_context.reward_eligible=enemy.rewards_enabled
func sync() -> void:
 for id in actors:
  if not is_instance_valid(actors[id]): continue
  var enemy:=actors[id] as Enemy
  if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.health_component.is_dead: continue
  var state: Dictionary=game.progress.story_actors.get(id,{})
  state["attitude"]="peaceful" if game.progress.claims.has(PEOPLE[id].claim) and enemy.story_truce else "watching" if enemy.story_truce else "hostile"
  state["materials"]=GrayriverLoot.snapshot(enemy).materials
  state["hp"]=enemy.health_component.hp
  game.progress.story_actors[id]=state
func _near(enemy: Enemy) -> bool:
 return not game._switching and is_instance_valid(enemy) and not enemy.health_component.is_dead and not game.player.health_component.is_dead and enemy.get_parent()==game.region_root and enemy.global_position.distance_to(game.player.global_position)<PlayerInputController.INTERACT_RANGE
func inspect(enemy: Enemy) -> bool:
 var id:=str(enemy.get_meta("frontier_claim",""))
 if not PEOPLE.has(id) or not _near(enemy) or game.practice_active or not enemy.has_meta("story_loot_eligible"): return false
 var person: Dictionary=PEOPLE[id]
 var settled:=game.progress.claims.has(person.claim)
 var carried:=GrayriverLoot.snapshot(enemy)
 var text: String={"bridge":"洛恩把剑挡在断桥西侧：‘镇里欠巡路队的粮已经两周。我要的是下一顿，不是你的命。带运料单来，证明货车确实翻了；或者留下一份烤饼。’","mine":"芮克守着两枚最后的导电晶石：‘欠货账我认。拿账来，我交出一枚；另一枚用两份烤饼换。装备是我自己的，不在货单里。’","veteran":"赫铎仍在执行多年前的封锁令：‘没有名册，我不能认你。带来档案窖名册，我会卸下岗哨责任；若你坚持动手，等我无力再战时，我也会认输。’"}[person.key]
 if settled: text="这段纠纷已经解决。"+{"bridge":"洛恩让开了道路，保留自己实际穿戴的装备。","mine":"芮克承认欠货，交易仍只取自他的剩余行囊。","veteran":"赫铎不再执行封锁令；其他守卫和领主仍需你亲自处理。"}[person.key]
 text+="\n\n当前穿戴与剩余物资：\n"
 for item_id in carried.equipment: text+=game.catalog.equipment[item_id].display_name+"\n"
 for item_id in carried.materials: text+="%s ×%d\n"%[game.survival.supplies.title(item_id),carried.materials[item_id]]
 text+="\n生命 %d/%d。攻击会终止停战；交涉不会赠送或复制装备。"%[enemy.health_component.hp,enemy.health_component.max_hp]
 var buttons: Array[Dictionary]=[]
 if not settled:
  match person.key:
   "bridge":
    buttons.append({"title":"出示翻车运料单","disabled":not game.progress.claims.has("river.caravan_manifest"),"callback":act.bind(enemy,"evidence")})
    buttons.append({"title":"交出一份烤饼","disabled":game.survival.supplies.count("ration")<1,"callback":act.bind(enemy,"food")})
   "mine": buttons.append({"title":"出示欠货账，确认剩余欠货","disabled":not game.progress.claims.has("river.quartermaster_note"),"callback":act.bind(enemy,"evidence")})
   "veteran":
    buttons.append({"title":"出示档案窖名册","disabled":not game.progress.claims.has("river.dossier"),"callback":act.bind(enemy,"evidence")})
    buttons.append({"title":"接受认输，停止交战","disabled":enemy.health_component.hp>enemy.health_component.max_hp*.35,"callback":act.bind(enemy,"surrender")})
 if person.key=="mine": buttons.append({"title":"两份烤饼换一枚剩余晶石","disabled":game.survival.supplies.count("ration")<2 or carried.materials.get("crystal",0)<1,"callback":act.bind(enemy,"trade")})
 buttons.append({"title":"结束停战，准备交战","callback":act.bind(enemy,"fight")})
 buttons.append({"title":"离开","callback":game.ui.close_modal})
 game.ui.show_panel(enemy.enemy_name+" · 交涉",text,buttons)
 return true
func act(enemy: Enemy, method: String) -> bool:
 if not _near(enemy) or game.practice_active: return false
 var id:=str(enemy.get_meta("frontier_claim",""))
 if not PEOPLE.has(id) or not enemy.has_meta("story_loot_eligible"): return false
 var person: Dictionary=PEOPLE[id]
 if method=="fight":
  enemy.story_truce=false
  game.session.relations.set_attitude(id,"player","hostile")
  if not game.active_enemies.has(enemy): game.active_enemies.append(enemy)
  game.progress.cleared.erase(game.region_id)
  game.ui.close_modal()
  sync(); game._save_progress()
  return true
 var settled:=game.progress.claims.has(person.claim)
 if settled and method!="trade": return false
 var costs: Dictionary={}
 var reward: Dictionary={}
 if method=="evidence":
  var clue: String={"bridge":"river.caravan_manifest","mine":"river.quartermaster_note","veteran":"river.dossier"}[person.key]
  if not game.progress.claims.has(clue): return false
  if person.key=="mine" and stock_count(enemy,"crystal")>0: reward={"crystal":1}
 elif method=="food" and person.key=="bridge": costs={"ration":1}
 elif method=="trade" and person.key=="mine": costs={"ration":2}; reward={"crystal":1}
 elif method=="surrender" and person.key=="veteran":
  if enemy.health_component.hp>enemy.health_component.max_hp*.35: return false
 else: return false
 var own:=game.survival.supplies
 var stock:=enemy.skill_manager.combinations.supplies
 if not own.can_pay(costs) or not stock.can_pay(reward): return false
 var notify: Callable
 var other_notify: Callable
 if own.inventory_store and stock.inventory_store==own.inventory_store:
  if not own.inventory_store.exchange(own.actor_id,stock.actor_id,costs,reward).accepted: return false
  notify=own.changed.emit
  other_notify=stock.changed.emit
 else:
  own.begin_transaction(); stock.begin_transaction()
  own.pay(costs); stock.pay(reward); own.grant(reward); stock.grant(costs)
  notify=own.finish_transaction(true)
  other_notify=stock.finish_transaction(true)
 if method!="trade":
  game.progress.claim(person.claim,person.title,"你与"+enemy.enemy_name+"达成协议。其装备与剩余物资仍归本人持有。",[],[])
  enemy.story_truce=true
  game.session.relations.set_attitude(id,"player","friendly")
  enemy._revenge_target=null
  enemy.attack_preparation.cancel()
  enemy.skill_manager.combinations.cancel("停战")
  enemy.rewards_enabled=false
  game.active_enemies.erase(enemy)
  if game.active_enemies.is_empty(): game.progress.cleared[game.region_id]=true
 sync()
 if notify.is_valid(): notify.call()
 if other_notify.is_valid(): other_notify.call()
 game._save_progress()
 inspect(enemy)
 return true
func died(enemy: Enemy) -> void:
 var id:=str(enemy.get_meta("frontier_claim",""))
 if not PEOPLE.has(id) or not enemy.has_meta("story_loot_eligible"): return
 game.progress.claim(PEOPLE[id].claim,PEOPLE[id].title,"你选择以战斗结束纠纷。可取走死者实际装备和剩余物资。",[],[])
 game.progress.story_actors.erase(id)
 actors.erase(id)
static func valid_states(value: Variant) -> bool:
 if not value is Dictionary or value.size()>3: return false
 for id in value:
  var state=value[id]
  if not PEOPLE.has(id) or not state is Dictionary or state.get("attitude","") not in ["watching","hostile","peaceful"]: return false
  if not state.get("hp") is int or state.hp<1 or state.hp>100000 or not state.get("materials") is Dictionary: return false
  for key in state.materials:
   if not key is String or not CastingSupplies.known_item(key) or not state.materials[key] is int or state.materials[key]<1 or state.materials[key]>999: return false
 return true

func stock_count(enemy: Enemy, id: String) -> int:
 return enemy.skill_manager.combinations.supplies.count(id)
