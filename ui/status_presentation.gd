class_name StatusPresentation
extends RefCounted
const HARMFUL := [Buff.Category.DEBUFF,Buff.Category.DOT,Buff.Category.CONTROL]
static func title(id: String,fallback: String) -> String:
 return {"burning":"燃烧","poison":"中毒","frozen":"冻结","wet":"浸湿","electrified":"感电"}.get(id,fallback)
## Read-only language shared by near-range enemy labels and the player HUD.
static func buildup_text(manager: BuffManager) -> String:
 var parts: PackedStringArray=[]
 var entries:=manager.buildup.snapshot()
 for id in entries:
  var definition:=WeaponEnchantment.definition(id)
  var value:=float(entries[id].value)
  parts.append("%s %.0f%%"%[title(definition.status.status_id,definition.status.display_name),100*value/definition.threshold])
 return "" if parts.is_empty() else "积累 · "+" / ".join(parts)+"（未生效）"
static func harmful_text(manager: BuffManager) -> String:
 var parts: PackedStringArray=[]
 for entry in manager.get_active_buff_entries():
  if entry.category not in HARMFUL: continue
  parts.append(title(str(entry.status_id),str(entry.name))+(" %d秒"%ceili(float(entry.remaining)) if entry.remaining>0 else ""))
 return "" if parts.is_empty() else "已生效 · "+" / ".join(parts)
