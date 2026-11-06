class_name ExplorationRegionData
extends Resource

@export var id: String
@export var title: String
@export_multiline var description: String
@export var room_type: String = "barracks"
@export var seed: int = 1
@export var encounters: Array[ExplorationEncounterData] = []
@export var discoveries: Array[ExplorationDiscoveryData] = []
@export var events: Array[ExplorationWorldEventData] = []
@export var spell_objects: Array[SpellPuzzleData] = []
@export var valves: Array[SurfaceValveData] = []
@export var surface_patches: Array[SurfacePatchData] = []
@export var fixed_props: Array[ExplorationPropData] = []
@export var facilities: Array[RepairFacilityData] = []
@export var survival_stations: Array[SurvivalStationData] = []
@export var exits: Array[ExplorationExitData] = []

func reserve_interaction_space(layout: RefCounted) -> void:
	# Authored points take precedence over the reusable random obstacle pattern.
	for obstacle in layout.obstacles.duplicate():
		var rect := Rect2(obstacle.position - obstacle.size * 0.5, obstacle.size).grow(48)
		for entry in interaction_points():
			if rect.has_point(entry.pos):
				layout.obstacles.erase(obstacle)
				break

func interaction_points() -> Array[Resource]:
	var points: Array[Resource] = []
	points.append_array(discoveries)
	points.append_array(events)
	points.append_array(exits)
	points.append_array(spell_objects)
	points.append_array(valves)
	points.append_array(fixed_props)
	points.append_array(facilities)
	points.append_array(survival_stations)
	for station in survival_stations:
		if station and station.kind == "cook":
			var heat := SurfacePatchData.new()
			heat.pos = station.pos + station.heat_offset
			points.append(heat)
	for patch in surface_patches:
		if patch: points.append_array(_patch_points(patch))
	for valve in valves:
		if not valve: continue
		for path in valve.paths:
			if not path: continue
			for point in path.points:
				var patch := SurfacePatchData.new()
				patch.pos = point
				points.append(patch)
	return points

func _patch_points(patch: SurfacePatchData) -> Array[Resource]:
	var result: Array[Resource] = [patch]
	for x in range(-ceili(patch.radius / 64), ceili(patch.radius / 64) + 1):
		for y in range(-ceili(patch.radius / 64), ceili(patch.radius / 64) + 1):
			var offset := Vector2(x, y) * 64
			if offset.length() > patch.radius: continue
			var point := SurfacePatchData.new()
			point.pos = patch.pos + offset
			result.append(point)
	return result
