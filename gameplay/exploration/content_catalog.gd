class_name ExplorationContentCatalog
extends RefCounted
var chapter: ExplorationChapterData
var regions: Dictionary = {}
var actions: Dictionary = {}
var spell_rules: Dictionary = {}
var equipment: Dictionary = {}

func _init(definition: ExplorationChapterData = null) -> void:
	chapter = definition if definition else load("res://content/exploration/chapter.tres") as ExplorationChapterData
	for region in chapter.regions:
		if region:
			regions[region.id] = region
	for action in chapter.actions:
		if action:
			actions[action.get_id()] = action
	for rule in chapter.spell_rules:
		if rule:
			spell_rules[rule.id] = rule
	for item in chapter.equipment:
		if item:
			equipment[item.id] = item

func fact(id: String) -> Dictionary:
	# Definitions remain the source of names, locations and prerequisites.
	for region: ExplorationRegionData in regions.values():
		for entries in [region.discoveries, region.spell_objects, region.facilities, region.delivery_sites, region.events]:
			for entry: Resource in entries:
				if entry.id == id:
					var prerequisites := PackedStringArray()
					if not entry is ExplorationDiscoveryData: prerequisites = entry.required_claims
					return {"title":entry.title,"region":region.id,"position":entry.pos,"definition":entry,"prerequisites":prerequisites,"kind":"discovery" if entry is ExplorationDiscoveryData else "objective"}
		for puzzle in region.spell_objects:
			if not puzzle.pickup_claim.is_empty() and puzzle.pickup_claim == id:
				return {"title":puzzle.pickup_title,"region":region.id,"position":puzzle.pos,"definition":puzzle,"prerequisites":PackedStringArray([puzzle.id]),"kind":"pickup"}
		for facility in region.facilities:
			if not facility.start_claim.is_empty() and facility.start_claim == id:
				return {"title":facility.title+"的检修记录","region":region.id,"position":facility.pos,"definition":facility,"prerequisites":PackedStringArray(),"kind":"discovery"}
		for event in region.events:
			for choice in event.choices:
				if id in choice.grants_claims:
					return {"title":choice.title,"region":region.id,"position":event.pos,"definition":event,"prerequisites":PackedStringArray([event.id]),"kind":"objective"}
	return {}

func passage_toward(origin: String, destination: String, progress: ExplorationProgress, point: Vector2) -> ExplorationExitData:
	if not regions.has(origin) or not regions.has(destination): return null
	var queue: Array[Dictionary] = [{"region":origin,"first":null}]
	var seen := {origin:true}
	while not queue.is_empty():
		var step: Dictionary = queue.pop_front()
		var exits: Array[ExplorationExitData] = []
		exits.assign(regions[step.region].exits)
		exits.sort_custom(func(a: ExplorationExitData,b: ExplorationExitData): return a.pos.distance_squared_to(point)<b.pos.distance_squared_to(point))
		for passage in exits:
			if not passage.claims_satisfied(progress) or seen.has(passage.target): continue
			var first: ExplorationExitData = passage if step.region == origin else step.first
			if passage.target == destination: return first
			seen[passage.target] = true
			queue.append({"region":passage.target,"first":first})
	return null

static func compass(delta: Vector2) -> String:
	if delta.length()<80: return "附近"
	return ["东","东南","南","西南","西","西北","北","东北"][posmod(roundi(delta.angle()/(PI/4)),8)]

func discovery_text(entry: ExplorationDiscoveryData, progress: ExplorationProgress, brief := false) -> String:
	var result := entry.intro_text if brief and not entry.intro_text.is_empty() else entry.text
	var origin := fact(entry.id)
	if origin.is_empty(): return result
	for hint in entry.navigation_hints:
		var destination := fact(hint.target_claim) if not hint.target_claim.is_empty() else {}
		var target_region: String = destination.get("region",hint.target_region)
		if not regions.has(target_region): continue
		var title: String = destination.get("title",regions[target_region].title)
		var point: Vector2 = destination.get("position",Vector2.ZERO)
		if target_region != origin.region:
			var passage := passage_toward(origin.region,target_region,progress,entry.pos)
			if not passage:
				result += "\n线索指向："+title+"；通路尚未接通。"
				continue
			point = passage.pos
		result += "\n从「%s」出发：%s方向 · %s%s。" % [entry.title,compass(point-entry.pos),title,"入口" if target_region!=origin.region else ""]
	return result

func record_text(record: Dictionary, progress: ExplorationProgress) -> String:
	var target := fact(str(record.get("id","")))
	if not target.is_empty() and target.definition is ExplorationDiscoveryData:
		return discovery_text(target.definition,progress)
	return str(record.get("text",""))
