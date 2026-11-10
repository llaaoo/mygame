class_name FieldcraftKnowledge
extends SaveRecord
## Session-owned knowledge, indexed by actor identity. No extra skill-point currency.
@export_storage var learned: Dictionary={}
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
	return true
