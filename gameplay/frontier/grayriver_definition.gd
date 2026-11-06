class_name GrayriverDefinition
extends RefCounted
const PATH := "res://content/frontier/grayriver.json"
static func vector(value: Array) -> Vector2: return Vector2(float(value[0]), float(value[1]))
static func amounts(value: Dictionary) -> Dictionary:
	var result := {}
	for id in value: result[id] = int(value[id])
	return result
static func data() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(PATH))
static func build() -> ExplorationChapterData:
	var source := ExplorationContentCatalog.new()
	var chapter := ExplorationChapterData.new()
	chapter.actions.assign(source.chapter.actions)
	chapter.spell_rules.assign(source.chapter.spell_rules)
	chapter.equipment.assign(source.chapter.equipment)
	var definition := data()
	for entry in definition.regions:
		var region := ExplorationRegionData.new()
		region.id = entry.id
		region.title = entry.title
		region.description = entry.description
		region.authored_size = vector(entry.size)
		region.authored_entry = vector(entry.entry)
		region.open_field = entry.get("open_field", false)
		region.room_type = entry.get("room_type", "barracks")
		for raw in entry.get("obstacles", []):
			region.authored_obstacles.append({"position": vector(raw.position), "size": vector(raw.size), "kind": raw.kind})
		if region.open_field:
			for span in [[-3600,-1710],[-1290,300],[700,2200],[2600,3600]]:
				region.authored_obstacles.append({"position":Vector2(300,(span[0]+span[1])*.5),"size":Vector2(260,span[1]-span[0]),"kind":"water"})
		for raw in entry.get("notes", []):
			var note := ExplorationDiscoveryData.new()
			if raw.has("template"):
				var parts: PackedStringArray = str(raw.template).split("/")
				for original in source.regions[parts[0]].discoveries:
					if original.id == parts[1]: note = original.duplicate(true)
			note.id = raw.id
			note.title = raw.title
			note.text = raw.text
			note.intro_text = raw.get("intro", raw.text)
			note.pos = vector(raw.pos)
			note.requires_clear = raw.get("requires_clear", false)
			note.heal = raw.get("heal", false)
			if raw.has("materials"): note.materials = amounts(raw.materials)
			if raw.has("equipment"): note.equipment.assign(raw.equipment)
			note.set_meta("crafting_recipes", raw.get("crafts", []))
			region.discoveries.append(note)
		for raw in entry.get("encounters", []):
			var encounter := ExplorationEncounterData.new()
			encounter.pos = vector(raw.pos)
			encounter.hp = int(raw.hp)
			encounter.speed = float(raw.get("speed", 105))
			encounter.boss = raw.get("boss", false)
			if raw.has("profile"): encounter.profile = load("res://content/exploration/enemies/%s.tres" % raw.profile)
			encounter.set_meta("persistent_id", str(raw.id))
			encounter.set_meta("group", str(raw.get("group", region.id)))
			region.encounters.append(encounter)
		for raw in entry.get("exits", []):
			var exit := ExplorationExitData.new()
			exit.target = raw.target
			exit.title = raw.title
			exit.pos = vector(raw.pos)
			if raw.has("arrival"): exit.arrival = vector(raw.arrival)
			region.exits.append(exit)
		for raw in entry.get("stations", []):
			var station := SurvivalStationData.new()
			for key in ["id", "title", "kind", "clean", "lit", "cleaned_by_claim"]:
				if raw.has(key): station.set(key, raw[key])
			station.pos = vector(raw.pos)
			station.harvest = amounts(raw.get("harvest", {}))
			station.required_claims = PackedStringArray(raw.get("required_claims", []))
			if raw.has("heat_offset"): station.heat_offset = vector(raw.heat_offset)
			region.survival_stations.append(station)
		for raw in entry.get("patches", []):
			var patch := SurfacePatchData.new()
			patch.pos = vector(raw.pos)
			patch.state = raw.state
			patch.radius = float(raw.radius)
			patch.duration = float(raw.duration)
			patch.disabled_by_claim = raw.get("disabled_by_claim", "")
			region.surface_patches.append(patch)
		for raw in entry.get("puzzles", []):
			var puzzle := SpellPuzzleData.new()
			if raw.has("template"):
				puzzle = load("res://content/exploration/%s.tres" % raw.template).duplicate(true)
			else:
				puzzle.id = raw.id
				puzzle.title = raw.title
				puzzle.hint = raw.hint
				puzzle.completion_text = raw.get("completion_text", "")
				puzzle.required_claims = PackedStringArray(raw.get("required_claims", []))
				puzzle.materials = amounts(raw.get("materials", {}))
				for route_data in raw.routes:
					var route := SpellPuzzleRoute.new()
					route.steps = PackedStringArray(route_data.get("steps", []))
					route.required_surface = route_data.get("required_surface", "")
					route.hold_seconds = float(route_data.get("hold_seconds", 0))
					puzzle.routes.append(route)
				for work_data in raw.get("work", []): puzzle.work_methods.append(work_method(work_data))
			puzzle.pos = vector(raw.pos)
			region.spell_objects.append(puzzle)
		for raw in entry.get("facilities", []):
			var facility := RepairFacilityData.new()
			if raw.has("template"): facility = load("res://content/exploration/%s.tres" % raw.template).duplicate(true)
			else:
				for key in ["id", "title", "service", "requires_clear", "description"]: facility.set(key, raw[key])
				facility.assembly = work_method(raw.assembly)
			facility.pos = vector(raw.pos)
			region.facilities.append(facility)
		for raw in entry.get("valves", []):
			var valve := SurfaceValveData.new()
			valve.id = raw.id
			valve.title = raw.title
			valve.pos = vector(raw.pos)
			for path_data in raw.paths:
				var path := WaterPathData.new()
				path.title = path_data.title
				for point in path_data.points: path.points.append(vector(point))
				valve.paths.append(path)
			region.valves.append(valve)
		if region.open_field:
			for house in [Vector2(-4250,1450),Vector2(-4100,2800),Vector2(-2550,2650)]:
				region.authored_obstacles.append({"position":house,"size":Vector2(230,150),"kind":"house"})
			var rng:=RandomNumberGenerator.new()
			rng.seed=162103
			for x in range(-4200,-1600,280):
				for y in range(-2700,100,280):
					var point:=Vector2(x+rng.randf_range(-60,60),y+rng.randf_range(-60,60))
					var clear:=true
					for interaction in region.interaction_points():
						if point.distance_to(interaction.pos)<135:clear=false
					for encounter in region.encounters:
						if point.distance_to(encounter.pos)<110:clear=false
					for road in definition.roads:
						for i in range(road.size()-1):
							if Geometry2D.get_closest_point_to_segment(point,vector(road[i]),vector(road[i+1])).distance_to(point)<140:clear=false
					if clear:region.authored_obstacles.append({"position":point,"size":Vector2(38,34),"kind":"tree"})
		chapter.regions.append(region)
	for raw in definition.quests:
		var quest := ExplorationQuestData.new()
		quest.id = raw.id
		quest.title = raw.title
		quest.description = raw.description
		quest.required_claims = PackedStringArray(raw.required_claims)
		quest.required_clears = PackedStringArray(raw.get("required_clears", []))
		quest.attribute_points = int(raw.points)
		chapter.quests.append(quest)
	return chapter

static func work_method(raw: Dictionary) -> FieldWorkMethod:
	var method := FieldWorkMethod.new()
	method.id = raw.id
	method.title = raw.title
	method.duration = float(raw.duration)
	method.material_costs = amounts(raw.get("material_costs", {}))
	return method
