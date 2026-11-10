class_name SpellFormAssist
extends RefCounted
## Transient casting context. Bindings and manual choices remain in QuickslotLoadout.
signal changed
const AFFINITIES := ["fire", "frost", "storm", "arcane", "ward", "water", "poison"]
var affinity := ""
var manager: SkillManager
func _init(owner: SkillManager) -> void:
 manager=owner
func supports(skill: SkillData) -> bool:
 if not skill or skill.operation_id=="disperse": return false
 var operation:=SpellOperationCatalog.default_catalog().operation(skill.operation_id)
 if not operation: return false
 return operation.payloads.any(func(payload: SpellPayloadData): return not payload.affinity.is_empty())
func automatic(source: String) -> bool:
 var instance:=manager.get_instance(source)
 var choice:=manager.shortcuts.selection(source)
 return instance and supports(instance.data) and choice.get("mode","")=="auto"
func resolve(source: String) -> Dictionary:
 var choice:=manager.shortcuts.selection(source)
 if not automatic(source): return choice
 return resolve_automatic(manager.get_instance(source).data)
func resolve_automatic(skill: SkillData) -> Dictionary:
 var operation:=SpellOperationCatalog.default_catalog().operation(skill.operation_id)
 if not affinity.is_empty():
  for payload in operation.payloads:
   if payload.affinity==affinity:
    return {"payload":payload.id,"modifier":"","uid":""}
 # No fallback to a different element when this action lacks a matching form.
 if not affinity.is_empty(): return {"payload":"","modifier":"","uid":""}
 return {"payload":operation.default_payload,"modifier":"","uid":""}
func unavailable_reason(skill: SkillData) -> String:
 if not supports(skill) or not resolve_automatic(skill).get("payload","").is_empty(): return ""
 return "等待一次成功施法确定元素，或用滚轮/G手动选择形式。" if affinity.is_empty() else "这个动作没有当前元素的形式；用滚轮/G手动选择，不会自动换成其他元素。"
func observe(plan: CastPlan) -> void:
 if not plan.action: return
 var operation:=SpellOperationCatalog.default_catalog().operation(plan.action.operation_id)
 var payload:=operation.payload(str(plan.selection.get("payload",""))) if operation else null
 var next:=payload.affinity if payload else ""
 if next.is_empty() and plan.skill:
  for tag in plan.skill.tags:
   var canonical: String={"ice":"frost","lightning":"storm"}.get(tag,tag)
   if canonical in AFFINITIES: next=canonical; break
 if next.is_empty() or next==affinity: return
 affinity=next; changed.emit()
func clear() -> void:
 if affinity.is_empty(): return
 affinity=""; changed.emit()
func label(source: String) -> String:
 return "智能跟随 · "+str({"":"等待施法","fire":"火","frost":"霜","storm":"雷","arcane":"凝能","ward":"守护","water":"水","poison":"毒"}.get(affinity,affinity)) if automatic(source) else "固定来源"
