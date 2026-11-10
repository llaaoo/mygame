class_name MapGeometry
extends RefCounted
## Authoring checks use the runtime's actual player clearance and navigation grid.
static func errors(region: ExplorationRegionData) -> Array[String]:
	var result: Array[String]=[]
	if not region.map_errors.is_empty(): return result
	var layout:=region.make_layout()
	region.reserve_interaction_space(layout)
	var source:=region.map_scene.resource_path+"::.: "
	for rule in region.map_arrival_rules.values():
		if rule.default_entry: source=str(rule.map_source)+": "
	if not layout.is_walkable(layout.entry_offset,20):
		result.append(source+"Default spawn is outside bounds or blocked")
		return result
	var navigation:=RegionNavigation.new();navigation.configure(layout)
	var points: Array[Dictionary]=[]
	for id in region.arrival_points:
		var rule: Dictionary=region.map_arrival_rules[id]
		var point: Vector2=region.arrival_points[id]
		points.append({"pos":point,"source":rule.map_source})
		for encounter in region.encounters:
			if rule.minimum_enemy_distance>0 and encounter.pos.distance_to(point)<rule.minimum_enemy_distance:
				result.append(str(rule.map_source)+": Enemy inside arrival clearance: "+id)
	for entry in region.interaction_points()+region.encounters:
		if entry.has_meta("map_source"): points.append({"pos":entry.pos,"source":entry.get_meta("map_source"),"radius":28 if entry is ExplorationEncounterData else 20})
	for point in points:
		if not layout.is_walkable(point.pos,int(point.get("radius",20))): result.append(str(point.source)+": Placement is outside bounds or blocked")
		elif navigation.path(layout.entry_offset,point.pos).is_empty(): result.append(str(point.source)+": Unreachable from default spawn on runtime navigation grid")
	return result
