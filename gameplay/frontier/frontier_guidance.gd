class_name FrontierGuidance
extends RefCounted
var game: GrayriverGame
func _init(owner_game: GrayriverGame) -> void: game=owner_game
func objective(id: String) -> Dictionary:
	if game.stories:
		var story := game.stories.objective(id)
		if not story.is_empty(): return story
	var target := game.catalog.fact(id)
	if not target.is_empty():
		return {"title":target.title,"region":target.region,"position":target.position,"known":known(target.region,target.position)}
	return {"title":"继续调查相关线索","region":"","position":Vector2.ZERO,"known":false}
func known(region: String, point: Vector2) -> bool:
	if region != "camp": return game.progress.visited.has(region)
	if game.progress.claims.has("fog.%d.%d" % [floori(point.x/512),floori(point.y/512)]): return true
	return game.region_id == region and game.player.position.distance_to(point)<420
func next_step(quest: ExplorationQuestData) -> Dictionary:
	if game.progress.claims.has("quest."+quest.id): return {}
	for id in quest.required_claims:
		if not game.progress.claims.has(id): return prerequisite_objective(id)
	for id in quest.required_clears:
		if not game.progress.cleared.has(id): return {"title":"处理"+game.catalog.regions[id].title+"的威胁","region":id,"position":game.catalog.regions[id].authored_entry,"known":game.progress.visited.has(id)}
	return {"title":"回镇向艾妲报告","region":"camp","position":Vector2(-2900,2200),"known":true}
func tracked() -> Dictionary:
	if not game.progress.waypoint.is_empty():
		return {"title":"自定路标","region":"camp","position":GrayriverDefinition.vector(game.progress.waypoint.position),"known":true}
	return goal_for(game.progress.tracked_quest)
func goal_for(id: String) -> Dictionary:
	for quest in game.quests:
		if quest.id==id: return next_step(quest)
	var detail:=game.session.conversations.favor_details(id)
	if detail.is_empty() or detail.state=="completed": return {}
	var profile:=detail.profile as NpcProfile; var entry:=detail.topic as NpcTopic
	if detail.dead: return {"title":entry.title+" · 原委托人已死亡","region":profile.region_id,"position":profile.work_location(),"known":false,"terminal":true}
	var missing: PackedStringArray=[]
	for item_id in entry.requested_items:
		var amount:=maxi(0,int(entry.requested_items[item_id])-game.session.inventory.count("player",item_id))
		if amount<=0: continue
		missing.append("%s ×%d"%[game.session.inventory.definitions[item_id].display_name,amount])
		var site:=known_gathering(item_id)
		if not site.is_empty(): return {"title":"收集："+missing[-1]+" · "+site.title,"region":site.region,"position":site.position,"known":true}
	if not missing.is_empty(): return {"title":"收集："+"、".join(missing)+" · 查看已学配方或寻找物资","region":"","position":Vector2.ZERO,"known":false}
	var npc:=game.session.actor_for_id(profile.actor_id)
	var routine:=profile.daily_schedule().get_entry_for_hour(float(game.session.hour_query.call()))
	var point: Vector2=npc.position if is_instance_valid(npc) else profile.rest_location() if routine and routine.target_marker=="rest" else profile.work_location()
	return {"title":("返回"+profile.character.title+"交付" if str(detail.reason).is_empty() else str(detail.reason)),"region":profile.region_id,"position":point,"known":true}
func known_gathering(item_id: String) -> Dictionary:
	var candidates: Array[Dictionary]=[]
	for region: ExplorationRegionData in game.catalog.regions.values():
		for station in region.survival_stations:
			if int(station.harvest.get(item_id,0))<=0 or not known(region.id,station.pos) or not game.progress.condition_query.claims_satisfied(station.required_claims) or float(game.survival.needs.harvests.get(station.id,0))>0: continue
			candidates.append({"title":station.title,"region":region.id,"position":station.pos})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary):
		if (a.region==game.region_id)!=(b.region==game.region_id): return a.region==game.region_id
		return a.position.distance_squared_to(game.player.position)<b.position.distance_squared_to(game.player.position))
	return candidates[0] if not candidates.is_empty() else {}

func town_orientation() -> Dictionary:
	if not game.is_at_base(): return {}
	for id in ["river.handbook", "river.pack"]:
		if not game.progress.claims.has(id): return prerequisite_objective(id)
	return {}

func route_target(goal: Dictionary) -> Vector2:
	if goal.is_empty() or goal.get("terminal",false) or str(goal.region).is_empty(): return Vector2.INF
	if game.region_id == goal.region: return goal.position if goal.known else Vector2.INF
	var passage := game.catalog.passage_toward(game.region_id,goal.region,game.progress,game.player.position)
	return passage.pos if passage else Vector2.INF

func prerequisite_objective(id: String, visited: Dictionary = {}) -> Dictionary:
	if visited.has(id): return objective(id)
	var next_visited := visited.duplicate()
	next_visited[id] = true
	var target := game.catalog.fact(id)
	for prerequisite in target.get("prerequisites",PackedStringArray()):
		if not game.progress.claims.has(prerequisite): return prerequisite_objective(prerequisite,next_visited)
	return objective(id)

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
	var goal:=goal_for(id)
	if goal.is_empty() or goal.get("terminal",false): return
	game.progress.tracked_quest = id
	game.progress.waypoint.clear()
	game._queue_save()
func set_waypoint(point: Vector2) -> void:
	if not point.is_finite(): return
	point = point.clamp(Vector2(-4750,-3550),Vector2(4750,3550))
	game.progress.waypoint = {"position":[point.x,point.y]}
	game._queue_save()
