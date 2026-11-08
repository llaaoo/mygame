class_name QuickslotMaterials
extends RefCounted
## Queries and explicit source changes shared by wheel and loadout. Never consumes stock.
static func operation(manager: SkillManager,source: String) -> SpellOperationData:
 var instance:=manager.get_instance(source)
 return SpellOperationCatalog.default_catalog().operation(instance.data.operation_id) if instance and manager.knows_action(instance.data) else null
static func available(manager: SkillManager,source: String) -> bool:
 var instance:=manager.get_instance(source)
 return instance and manager.knows_action(instance.data) and (not instance.data.operation_id.is_empty() or instance.data.get_id() in ["ignite","pulse","water_call"])
static func source_for(manager: SkillManager,skill: SkillData,preferred := "") -> String:
 var candidates: Array[String]=[]
 if preferred in QuickslotLoadout.SOURCES: candidates.append(preferred)
 for source in QuickslotLoadout.SOURCES:
  if source not in candidates: candidates.append(source)
 for source in candidates:
  var instance:=manager.get_instance(source)
  if instance and instance.data.get_id()==skill.get_id(): return source
 return ""
static func modifier_ids(manager: SkillManager,skill: SkillData) -> Array[String]:
 var supplies:=manager.combinations.supplies
 var candidates: Array[String]=[""]
 for id: String in CastingSupplies.MATERIAL_IDS:
  var material:=supplies.catalog[id] as CastingMaterialData
  var compatible:=material.supports(skill.get_id(),skill.get_id(),skill)
  for rule in manager.combinations.rules:
   if rule.trigger_action_id==skill.get_id() and manager.combinations.learned_rules.has(rule.id) and material.supports(skill.get_id(),rule.result_skill.get_id(),rule.result_skill): compatible=true
  if compatible: candidates.append(id)
 return candidates
static func _basic_options(actor: Player,source: String) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 var manager:=actor.skill_manager
 var skill:=manager.get_instance(source).data
 var supplies:=manager.combinations.supplies
 var current:=manager.selection_for_source(source)
 var candidates:=modifier_ids(manager,skill)
 for id in candidates:
  var choice: Dictionary={"payload":"","modifier":id,"uid":""}
  var plan:=manager.combinations.preview(skill,actor,Input.is_key_pressed(KEY_SHIFT),choice)
  var material:=supplies.catalog.get(id) as CastingMaterialData
  var detail:="不加额外材料" if id.is_empty() else "口袋 ×%d"%actor.actor_context.items.count(actor.actor_context.id,id,false,true)
  if material and plan.material_costs.is_empty(): detail+=" · 当前结果不适配，不会消费"
  result.append({"variant_id":"modifier:"+id,"title":supplies.title(id) if material else "基础","choice":choice,"cost":plan.cost,"ready":plan.ready,"reason":plan.reason,"detail":detail,"description":material.description if material else "按原本基础动作施放。","current":current==choice})
 return result
static func options(actor: Player,source: String) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 var manager:=actor.skill_manager
 var entry:=operation(manager,source)
 if not actor.actor_context or not available(manager,source): return result
 if not entry: return _basic_options(actor,source)
 var store:=actor.actor_context.items
 var current:=manager.selection_for_source(source)
 var automatic:=manager.spell_forms.automatic(source)
 if manager.spell_forms.supports(entry.action):
  var preview:=manager.combinations.preview(entry.action,actor,Input.is_key_pressed(KEY_SHIFT),manager.spell_forms.resolve_automatic(entry.action))
  var reason:=manager.spell_forms.unavailable_reason(entry.action)
  if not reason.is_empty(): preview.ready=false; preview.reason=reason
  var following:=entry.payload(str(manager.spell_forms.resolve_automatic(entry.action).get("payload","")))
  var auto_detail:=manager.spell_forms.label(source) if automatic else "跟随最近成功施法的元素"
  auto_detail+=" · "+stock_text(actor,preview.material_costs)
  if following and not following.source_kind.is_empty(): auto_detail+=" · "+_source_hint(following)
  if following and following.required_rule: auto_detail+=" · "+following.required_rule.condition_label()
  result.append({"variant_id":"auto","title":"跟随·"+following.title if following else "智能跟随","choice":{"mode":"auto"},"cost":preview.cost,"ready":preview.ready,"reason":preview.reason,"detail":auto_detail,"description":"只改变后续形式；仍须真实来源和手动释放。滚轮/M可固定形式。","current":automatic})
 for payload in entry.payloads:
  var choice: Dictionary={"payload":payload.id,"modifier":str(current.get("modifier","")),"uid":""}
  var composed:=entry.compose(payload)
  var modifier:=manager.combinations.supplies.catalog.get(choice.modifier) as CastingMaterialData
  if modifier and not modifier.supports(entry.action.get_id(),composed.get_id(),composed): choice.modifier=""
  var uids: Array[String]=[]
  if entry.action.operation_id=="disperse":
   for row in store.entries(actor.actor_context.id+".pocket"):
    if row.definition==payload.material_id: uids.append(row.uid)
  if uids.is_empty(): uids.append("")
  for uid in uids:
   var selected:=choice.duplicate(true); selected.uid=uid
   var plan:=manager.combinations.preview(entry.action,actor,Input.is_key_pressed(KEY_SHIFT),selected)
   var count:=store.count(actor.actor_context.id,payload.material_id,false,true) if not payload.material_id.is_empty() else -1
   var item:=store.item(uid) if not uid.is_empty() else null
   var detail: String="无需实物" if count<0 else "口袋%d / 背包%d"%[count,maxi(0,store.count(actor.actor_context.id,payload.material_id)-count)]
   if item: detail="瓶 %s · %s"%[uid.trim_prefix("item."),store.state_text(uid)]
   if not current.get("modifier","").is_empty() and selected.modifier.is_empty(): detail+=" · 确认将移除不适配修饰"
   if not payload.source_kind.is_empty(): detail+=" · "+_source_hint(payload)
   if payload.required_rule: detail+=" · "+payload.required_rule.condition_label()
   result.append({"variant_id":payload.id,"title":payload.title,"choice":selected,"cost":plan.cost,"ready":plan.ready,"reason":plan.reason,"detail":detail,"description":payload.describe(actor.actor_context.rules.timed_fields),"current":not automatic and current==selected})
 return result
static func select(actor: Player,source: String,choice: Dictionary) -> bool:
 if not actor.actor_context or actor.health_component.is_dead: return false
 if not available(actor.skill_manager,source): return false
 var entry:=operation(actor.skill_manager,source)
 if choice=={"mode":"auto"}:
  return actor.skill_manager.spell_forms.supports(actor.skill_manager.get_instance(source).data) and actor.skill_manager.shortcuts.set_selection(source,choice)
 if not entry:
  for candidate in _basic_options(actor,source):
   if candidate.choice==choice: return actor.skill_manager.shortcuts.set_selection(source,choice)
  return false
 if not entry.payload(str(choice.get("payload",""))): return false
 var uid:=str(choice.get("uid",""))
 if entry.action.operation_id=="disperse" and uid.is_empty(): return false
 if not uid.is_empty():
  var item:=actor.actor_context.items.item(uid)
  if not item or item.definition_id!=entry.payload(str(choice.payload)).material_id or actor.actor_context.items.locate(uid)!=actor.actor_context.id+".pocket": return false
 # Selecting missing material is allowed and remains visibly unavailable; no implicit fallback.
 return actor.skill_manager.shortcuts.set_selection(source,choice)

static func cycle(actor: Player,source: String,step: int) -> bool:
 var entries:=options(actor,source)
 if entries.is_empty(): return false
 var actual:=actor.skill_manager.selection_for_source(source)
 var index:=-1
 for i in range(entries.size()):
  if entries[i].current: index=i; break
 if index<0 and step<0: index=0
 for offset in range(1,entries.size()+1):
  var candidate: Dictionary=entries[posmod(index+step*offset,entries.size())]
  var candidate_actual: Dictionary=actor.skill_manager.spell_forms.resolve_automatic(actor.skill_manager.get_instance(source).data) if candidate.choice.get("mode","")=="auto" else candidate.choice
  if candidate_actual==actual: continue
  if select(actor,source,candidate.choice):
   var message: String=InputBindings.label(InputBindings.action_for_source(source))+" · "+str(candidate.title)+" · "+str(candidate.detail)
   if not candidate.ready: message+="\n"+str(candidate.reason)
   actor.skill_manager.combinations.report_feedback(message)
   return true
 return false
static func stock_text(actor: Node2D,costs: Dictionary) -> String:
 if not actor or not "actor_context" in actor or not actor.actor_context: return ""
 var parts: PackedStringArray=[]
 var context: ActorContext=actor.actor_context
 for id in costs:
  var pocket:=context.items.count(context.id,id,false,true)
  var pack:=maxi(0,context.items.count(context.id,id)-pocket)
  var definition:=ItemCatalog.default_catalog().definition(id)
  parts.append("%s：口袋%d / 背包%d · 需%d"%[definition.display_name if definition else id,pocket,pack,costs[id]])
 return "；".join(parts)

static func _source_hint(payload: SpellPayloadData) -> String:
 return "脚下"+FireSigil.title_for(payload.source_field)+"充能" if payload.source_kind=="field" else "附近真实残魂"
