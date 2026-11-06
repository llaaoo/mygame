class_name LootSchema
extends RefCounted
## Legacy wire adapter validation. Definitions come from a catalog, not a chapter class.
static func valid_records(value: Variant) -> bool:
	if not value is Dictionary or value.size()>512: return false
	for id in value:
		var record=value[id]
		if not id is String or not record is Dictionary or not record.get("region") is String or not record.get("title") is String: return false
		var point=record.get("position")
		if not point is Array or point.size()!=2: return false
		for n in point:
			if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or absf(float(n))>100000: return false
		for kind in ["equipment","materials"]:
			if not record.get(kind) is Dictionary: return false
			for key in record[kind]:
				if not key is String or not record[kind][key] is int or record[kind][key]<=0 or record[kind][key]>999: return false
				var item:=ItemCatalog.default_catalog().definition(key)
				if not item or (kind=="equipment")!=(item is EquipmentData): return false
	return true
