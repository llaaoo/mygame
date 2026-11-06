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
func route_target(goal: Dictionary) -> Vector2:
	if goal.is_empty() or not goal.known: return Vector2.INF
	if game.region_id == goal.region: return goal.position
	var candidates: Array[ExplorationExitData]=[]
	if game.region_id!="camp":
		for exit in game.current_data.exits:
			if exit.target=="camp" and exit.claims_satisfied(game.progress): candidates.append(exit)
		candidates.sort_custom(func(a: ExplorationExitData,b: ExplorationExitData): return a.pos.distance_to(game.player.position)+a.arrival.distance_to(goal.position)<b.pos.distance_to(game.player.position)+b.arrival.distance_to(goal.position))
	else:
		for exit in game.current_data.exits:
			if exit.target==goal.region and exit.claims_satisfied(game.progress): candidates.append(exit)
		candidates.sort_custom(func(a: ExplorationExitData,b: ExplorationExitData): return a.pos.distance_to(game.player.position)<b.pos.distance_to(game.player.position))
	if not candidates.is_empty(): return candidates[0].pos
	return Vector2.INF
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
