class_name HarvestPart
extends Resource
## One finite anatomical source. Its value snapshot is attached to a real raw UID.
@export var id := ""
@export var title := ""
@export var raw_item := ""
@export var skill_id := ""
@export var tool_id := "field_knife"
@export var outputs: Dictionary={}
@export var duration := 3.0
func snapshot() -> Dictionary:
	return {"id":id,"title":title,"raw_item":raw_item,"skill":skill_id,"tool":tool_id,"outputs":outputs.duplicate(true),"duration":duration}
static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["id","title","raw_item","skill","tool"]:
		if not value.get(key) is String or str(value[key]).is_empty(): return false
	if not FieldcraftCatalog.default_catalog().skill(value.skill): return false
	for key in [value.raw_item,value.tool]:
		if not ItemCatalog.default_catalog().definition(key): return false
	var raw:=ItemCatalog.default_catalog().definition(value.raw_item)
	if raw.stackable or raw.max_stack!=1: return false
	if typeof(value.get("duration")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.duration)) or value.duration<=0 or value.duration>30: return false
	if not value.get("outputs") is Dictionary or value.outputs.is_empty() or value.outputs.size()>8: return false
	for key in value.outputs:
		if not key is String or key==value.raw_item or not ItemCatalog.default_catalog().definition(key) or not value.outputs[key] is int or value.outputs[key]<1 or value.outputs[key]>20: return false
	return true
