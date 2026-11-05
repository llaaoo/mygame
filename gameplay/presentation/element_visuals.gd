class_name ElementVisuals
extends RefCounted
## Presentation palette only. Combat affinities and reactions remain in their catalogs.
static func color_for(tags: Array[String]) -> Color:
	for id in ["ice", "lightning", "poison", "fire", "water", "soul", "shadow", "arcane"]:
		if id in tags:
			var entry := ElementCatalog.definition(id)
			if entry: return Color(entry.color, 1)
			return Color("b0a0ed") if id in ["soul", "shadow"] else Color("dcc799")
	return Color("d6c7a1")

static func status_color(id: String) -> Color:
	var tag: String = {"ember_focus": "fire", "burning": "fire", "frost_stride": "ice", "frozen": "ice", "flow_attunement": "water", "wet": "water", "static_focus": "lightning", "shocked": "lightning", "venom_accord": "poison", "poison": "poison", "soul_charge": "soul", "ancestral_ward": "soul", "echo_ready": "water", "resonant_guard": "water"}.get(id, "")
	return color_for([tag])
