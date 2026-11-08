class_name FrontierGuidance
extends RefCounted
var game: GrayriverGame
func _init(owner_game: GrayriverGame) -> void: game=owner_game
func objective(id: String) -> Dictionary:
	if game.stories:
		var story := game.stories.objective(id)
		if not story.is_empty(): return story
	for region: ExplorationRegionData in game.catalog.regions.values():
		for entries in [region.discoveries,region.spell_objects,region.facilities,region.delivery_sites,region.events]:
			for entry in entries:
				if entry.id == id:
					return {"title":entry.title,"region":region.id,"position":entry.pos,"known":known(region.id,entry.pos)}
	return {"title":"继续调查相关线索","region":"","position":Vector2.ZERO,"known":false}
func known(region: String, point: Vector2) -> bool:
	if region != "camp": return game.progress.visited.has(region)
	if game.progress.claims.has("fog.%d.%d" % [floori(point.x/512),floori(point.y/512)]): return true
	return game.region_id == region and game.player.position.distance_to(point)<420
func next_step(quest: ExplorationQuestData) -> Dictionary:
	if game.progress.claims.has("quest."+quest.id): return {}
	for id in quest.required_claims:
		if not game.progress.claims.has(id): return objective(id)
	for id in quest.required_clears:
		if not game.progress.cleared.has(id): return {"title":"处理"+game.catalog.regions[id].title+"的威胁","region":id,"position":game.catalog.regions[id].authored_entry,"known":game.progress.visited.has(id)}
	return {"title":"回镇向艾妲报告","region":"camp","position":Vector2(-2900,2200),"known":true}
func tracked() -> Dictionary:
	if not game.progress.waypoint.is_empty():
		return {"title":"自定路标","region":"camp","position":GrayriverDefinition.vector(game.progress.waypoint.position),"known":true}
	for quest in game.quests:
		if quest.id == game.progress.tracked_quest: return next_step(quest)
	return {}

func town_orientation() -> Dictionary:
	if not game.is_at_base(): return {}
	for id in ["river.handbook", "river.pack"]:
		if not game.progress.claims.has(id): return objective(id)
	return {}

func route_target(goal: Dictionary) -> Vector2:
	if goal.is_empty() or str(goal.region).is_empty(): return Vector2.INF
	if game.region_id == goal.region: return goal.position if goal.known else Vector2.INF
	# Search the actual exit graph: lower floors need their parent stair, not
	# a nonexistent direct camp exit. Only already-open gates are traversable.
	var queue: Array[Dictionary] = [{"region":game.region_id,"first":Vector2.INF}]
	var seen: Dictionary = {game.region_id:true}
	while not queue.is_empty():
		var step: Dictionary = queue.pop_front()
		var exits: Array[ExplorationExitData] = []
		exits.assign(game.catalog.regions[step.region].exits)
		exits.sort_custom(func(a: ExplorationExitData,b: ExplorationExitData): return a.pos.distance_squared_to(game.player.position)<b.pos.distance_squared_to(game.player.position))
		for passage in exits:
			if not passage.claims_satisfied(game.progress) or seen.has(passage.target): continue
			var first: Vector2 = passage.pos if step.region == game.region_id else step.first
			if passage.target == goal.region: return first
			seen[passage.target] = true
			queue.append({"region":passage.target,"first":first})
	return Vector2.INF
func overworld_point(region: String) -> Vector2:
	# Follow the authored return chain, including parents of deeper floors.
	var seen: Dictionary = {}
	while region != "camp" and not seen.has(region) and game.catalog.regions.has(region):
		seen[region] = true
		var exits: Array[ExplorationExitData] = game.catalog.regions[region].exits
		if exits.is_empty(): break
		var passage := exits[0]
		if passage.target == "camp": return passage.arrival
		region = passage.target
	return Vector2.ZERO
func pin(id: String) -> void:
	if not game.quests.any(func(quest): return quest.id == id): return
	game.progress.tracked_quest = id
	game.progress.waypoint.clear()
	game._queue_save()
func set_waypoint(point: Vector2) -> void:
	if not point.is_finite(): return
	point = point.clamp(Vector2(-4750,-3550),Vector2(4750,3550))
	game.progress.waypoint = {"position":[point.x,point.y]}
	game._queue_save()
