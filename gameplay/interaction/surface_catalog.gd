class_name SurfaceCatalog
extends RefCounted
const STATE_IDS := ["dry", "wet", "frozen", "oiled", "burning", "electrified", "steam", "poisoned"]
const RULE_IDS := ["oil_fire", "wet_ice", "wet_fire", "burn_ice", "burn_wet", "dry_fire", "dry_ice", "frozen_impact", "wet_lightning", "frozen_fire", "dry_water", "electrified_ice", "poisoned_fire", "poisoned_water", "poisoned_ice", "wet_poison"]
static var _states: Array[SurfaceDefinition] = []
static var _rules: Array[SurfaceReaction] = []

static func all_definitions() -> Array[SurfaceDefinition]:
	if _states.is_empty():
		for id in STATE_IDS:
			_states.append(load("res://content/surfaces/%s.tres" % id) as SurfaceDefinition)
	return _states.duplicate()

static func definition(id: String) -> SurfaceDefinition:
	for entry in all_definitions():
		if entry.id == id: return entry
	return null

static func all_reactions() -> Array[SurfaceReaction]:
	if _rules.is_empty():
		for id in RULE_IDS:
			_rules.append(load("res://content/surfaces/reactions/%s.tres" % id) as SurfaceReaction)
	return _rules.duplicate()

static func color_for(state: String) -> Color:
	var entry := definition(state)
	return entry.color if entry else Color.TRANSPARENT
