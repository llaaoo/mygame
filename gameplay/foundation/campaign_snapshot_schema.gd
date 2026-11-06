class_name CampaignSnapshotSchema
extends RefCounted
static func valid_legacy_actors(value: Variant) -> bool:
	if not value is Dictionary or value.size()>512: return false
	for id in value:
		var state=value[id]
		if not id is String or not state is Dictionary or state.get("attitude","") not in ["watching","hostile","peaceful"]: return false
		if not state.get("hp") is int or state.hp<1 or state.hp>100000 or not state.get("materials") is Dictionary: return false
		for key in state.materials:
			if not key is String or not CastingSupplies.known_item(key) or not state.materials[key] is int or state.materials[key]<1 or state.materials[key]>999: return false
	return true
