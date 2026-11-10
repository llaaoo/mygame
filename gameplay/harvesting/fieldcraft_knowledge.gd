class_name FieldcraftKnowledge
extends SaveRecord
## Session-owned knowledge, indexed by actor identity. No extra skill-point currency.
@export_storage var learned: Dictionary={}
@export_storage var harvested: Dictionary={}
func record_harvest(actor_id: String,uid: String,skill_id: String) -> bool:
	if uid.is_empty() or harvested.has(uid) or not knows(actor_id,skill_id): return false
	harvested[uid]={"actor":actor_id,"skill":skill_id}
	return true
func harvest_count(actor_id: String,skill_id: String) -> int:
	return harvested.values().filter(func(entry: Dictionary):return entry.actor==actor_id and entry.skill==skill_id).size()
func knows(actor_id: String,skill_id: String) -> bool:
	return bool(learned.get(actor_id,{}).get(skill_id,false))
func reason(actor_id: String,skill_id: String) -> String:
	var entry:=FieldcraftCatalog.default_catalog().skill(skill_id)
	if not entry: return "未知野外技艺"
	if knows(actor_id,skill_id): return "已学会"
	for required in entry.prerequisites:
		if not knows(actor_id,required): return "先学习："+FieldcraftCatalog.default_catalog().skill(required).title
	return ""
func learn(actor_id: String,skill_id: String) -> bool:
	if actor_id.is_empty() or not reason(actor_id,skill_id).is_empty(): return false
	if not learned.has(actor_id): learned[actor_id]={}
	learned[actor_id][skill_id]=true
	return true
func validate_save_data(value: Variant) -> bool:
	if not super.validate_save_data(value): return false
	var records: Dictionary=value.get("learned",{})
	if records.size()>4096: return false
	for actor_id in records:
		if not actor_id is String or actor_id.is_empty() or not records[actor_id] is Dictionary: return false
		for key in records[actor_id]:
			if not key is String or not FieldcraftCatalog.default_catalog().skill(key) or not records[actor_id][key] is bool or not records[actor_id][key]: return false
			for required in FieldcraftCatalog.default_catalog().skill(key).prerequisites:
				if not records[actor_id].get(required,false): return false
	var receipts: Dictionary=value.get("harvested",{})
	if receipts.size()>4096: return false
	for uid in receipts:
		var entry: Variant=receipts[uid]
		if not uid is String or not uid.begins_with("item.") or not entry is Dictionary or not entry.get("actor") is String or not entry.get("skill") is String or not records.get(entry.actor,{}).get(entry.skill,false): return false
	return true
