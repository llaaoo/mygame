class_name GrayriverDefinition
extends RefCounted
const PATH := "res://content/frontier/grayriver.json"
static func vector(value: Array) -> Vector2: return Vector2(float(value[0]), float(value[1]))
static func amounts(value: Dictionary) -> Dictionary:
	var result := {}
	for id in value: result[id] = int(value[id])
	return result
static func data() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(PATH))
static func build(map_catalog: MapCellCatalog=null,resolve_connections := true) -> ExplorationChapterData:
	var source := ExplorationContentCatalog.new()
	var chapter := ExplorationChapterData.new()
	chapter.actions.assign(source.chapter.actions)
	chapter.spell_rules.assign(source.chapter.spell_rules)
	# Content assembly references definitions, not the runtime payload/effect registry.
	for id in ["project","shape","step","sustain"]:
		chapter.actions.append(load("res://content/spell_operations/%s.tres"%id) as SkillData)
	chapter.equipment.assign(ItemCatalog.default_catalog().equipment())
	var definition := data()
	for entry in definition.regions:
		var region := ExplorationRegionData.new()
		region.id = entry.id
		region.title = entry.title
		region.description = entry.description
		region.authored_size = vector(entry.size)
		region.authored_entry = vector(entry.entry)
		region.open_field = entry.get("open_field", false)
		if entry.has("presentation_environment"): region.presentation_environment=load(entry.presentation_environment) as EnvironmentProfile
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
			note.reading_margin = float(raw.get("reading_margin", 0))
			note.kind = raw.get("kind",note.kind)
			if raw.has("materials"): note.materials = amounts(raw.materials)
			for id in raw.get("actions",[]):
				if id not in note.actions: note.actions.append(id)
			if raw.has("equipment"): note.equipment.assign(raw.equipment)
			for lead in raw.get("leads", []):
				var hint := ExplorationNavigationHint.new()
				hint.target_region = lead.get("region", "")
				hint.target_claim = lead.get("claim", "")
				note.navigation_hints.append(hint)
			note.set_meta("crafting_recipes", raw.get("crafts", []))
			region.discoveries.append(note)
		for raw in entry.get("deliveries", []):
			var site:=DeliverySiteData.new()
			site.id=raw.id
			site.title=raw.title
			site.pos=vector(raw.pos)
			site.description=raw.description
			site.completion_text=raw.get("completion_text",site.completion_text)
			site.already_text=raw.get("already_text",site.already_text)
			site.rewards=amounts(raw.get("rewards",{}))
			site.required_claims=PackedStringArray(raw.get("required_claims",[]))
			for work_data in raw.methods:site.methods.append(work_method(work_data))
			region.delivery_sites.append(site)
		for raw in entry.get("encounters", []):
			var encounter := ExplorationEncounterData.new()
			encounter.pos = vector(raw.pos)
			encounter.hp = int(raw.get("hp",1))
			if raw.has("character"): encounter.character=load("res://content/characters/river_%s.tres"%raw.character)
			if raw.has("tactics"):encounter.tactics=load("res://content/tactics/territories/%s.tres"%raw.tactics) as EncounterTactics
			encounter.speed = float(raw.get("speed", 105))
			encounter.detect_range = float(raw.get("detect_range", 440))
			encounter.boss = raw.get("boss", false)
			encounter.optional_encounter = raw.get("optional", false)
			if raw.has("profile"): encounter.profile = load("res://content/exploration/enemies/%s.tres" % raw.profile)
			encounter.persistent_id=str(raw.id)
			encounter.group=str(raw.get("group",region.id))
			encounter.set_meta("persistent_id",encounter.persistent_id)
			encounter.set_meta("group",encounter.group)
			region.encounters.append(encounter)
		for raw in entry.get("exits", []):
			var exit := ExplorationExitData.new()
			exit.target = raw.target
			exit.title = raw.title
			exit.pos = vector(raw.pos)
			exit.required_claims=PackedStringArray(raw.get("required_claims",[]))
			exit.locked_message=raw.get("locked_message",exit.locked_message)
			if raw.has("arrival"): exit.arrival = vector(raw.arrival)
			region.exits.append(exit)
		for raw in entry.get("stations", []):
			var station := SurvivalStationData.new()
			for key in ["id", "title", "kind", "clean", "lit", "cleaned_by_claim"]:
				if raw.has(key): station.set(key, raw[key])
			station.pos = vector(raw.pos)
			station.harvest = amounts(raw.get("harvest", {}))
			station.regeneration_hours=float(raw.get("regeneration_hours",4))
			station.required_claims = PackedStringArray(raw.get("required_claims", []))
			if raw.has("presentation_profile"): station.presentation_profile=load(raw.presentation_profile) as WorldAnimationProfile
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
					route.id = route_data.get("id", "")
					route.steps = PackedStringArray(route_data.get("steps", []))
					route.required_surface = route_data.get("required_surface", "")
					route.hold_seconds = float(route_data.get("hold_seconds", 0))
					puzzle.routes.append(route)
				for work_data in raw.get("work", []): puzzle.work_methods.append(work_method(work_data))
			puzzle.pos = vector(raw.pos)
			if raw.has("presentation_profile"): puzzle.presentation_profile=load(raw.presentation_profile) as WorldAnimationProfile
			region.spell_objects.append(puzzle)
		for raw in entry.get("facilities", []):
			var facility := RepairFacilityData.new()
			if raw.has("template"): facility = load("res://content/exploration/%s.tres" % raw.template).duplicate(true)
			else:
				for key in ["id", "title", "service", "requires_clear", "description"]: facility.set(key, raw[key])
				facility.required_claims = PackedStringArray(raw.get("required_claims", []))
				facility.completion_text = raw.get("completion_text", "")
				facility.assembly = work_method(raw.assembly)
			facility.pos = vector(raw.pos)
			region.facilities.append(facility)
		for raw in entry.get("props", []):
			var prop:=ExplorationPropData.new()
			prop.id=raw.id
			prop.pos=vector(raw.pos)
			prop.scene=load("res://world/object/%s.tscn" % raw.scene)
			region.fixed_props.append(prop)
		for raw in entry.get("events", []):
			var event:=ExplorationWorldEventData.new()
			event.id=raw.id
			event.title=raw.title
			event.text=raw.text
			event.irreversible=raw.get("irreversible",false)
			event.pos=vector(raw.pos)
			event.required_claims=PackedStringArray(raw.get("required_claims",[]))
			for choice_data in raw.choices:
				var choice:=ExplorationWorldChoiceData.new()
				choice.id=choice_data.id
				choice.title=choice_data.title
				choice.text=choice_data.text
				choice.grants_claims=PackedStringArray(choice_data.get("grants_claims",[]))
				event.choices.append(choice)
			region.events.append(event)
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
	var maps:=map_catalog if map_catalog else load("res://content/maps/grayriver/catalog.tres") as MapCellCatalog
	maps.append_to(chapter,resolve_connections)
	for raw in definition.quests:
		var quest := ExplorationQuestData.new()
		quest.id = raw.id
		quest.title = raw.title
		quest.description = raw.description
		quest.discovery_claims = PackedStringArray(raw.get("discovery_claims", []))
		quest.unlock_claims = PackedStringArray(raw.get("unlock_claims", []))
		quest.required_claims = PackedStringArray(raw.required_claims)
		quest.required_clears = PackedStringArray(raw.get("required_clears", []))
		quest.attribute_points = int(raw.points)
		chapter.quests.append(quest)
	chapter.quests.append(load("res://content/frontier/quests/hunting_evidence.tres") as ExplorationQuestData)
	return chapter

static func work_method(raw: Dictionary) -> FieldWorkMethod:
	var method := FieldWorkMethod.new()
	method.animation_id=StringName(raw.get("animation_id",""))
	method.id = raw.id
	method.title = raw.title
	method.duration = float(raw.duration)
	method.material_costs = amounts(raw.get("material_costs", {}))
	return method
