class_name MapConnections
extends RefCounted
## Resolve after every cell has compiled. Never instantiate a destination at travel time.
static func resolve(chapter: ExplorationChapterData) -> void:
	var regions: Dictionary={};var passages: Dictionary={}
	for region in chapter.regions: regions[region.id]=region
	for region in chapter.regions:
		for passage in region.exits:
			if passage.id.is_empty(): continue # Legacy JSON entrances remain compatible.
			if passages.has(passage.id): _fail(region,passage,"Duplicate passage identity: "+passage.id)
			else: passages[passage.id]={"region":region.id,"exit":passage}
	for region in chapter.regions:
		for passage in region.exits:
			if not passage.target_anchor.is_empty():
				var destination: ExplorationRegionData=regions.get(passage.target)
				if not destination or not destination.arrival_points.has(passage.target_anchor):
					_fail(region,passage,"Missing target arrival: %s/%s"%[passage.target,passage.target_anchor])
				else: passage.arrival=destination.arrival_points[passage.target_anchor]
			if not passage.return_exit.is_empty():
				var counterpart: Dictionary=passages.get(passage.return_exit,{})
				if counterpart.is_empty() or counterpart.region!=passage.target or counterpart.exit.target!=region.id or counterpart.exit.return_exit!=passage.id:
					_fail(region,passage,"Mismatched return passage: "+passage.return_exit)
	# Overworld projection follows each region's first return, not arbitrary graph search.
	for region in chapter.regions:
		if not region.map_scene or region.id=="camp": continue
		var current: ExplorationRegionData=region;var seen: Dictionary={}
		while current.id!="camp":
			if seen.has(current.id) or current.exits.is_empty():
				region.map_errors.append(region.map_scene.resource_path+"::.: Primary return chain must reach camp without cycles")
				break
			seen[current.id]=true
			var first:=current.exits[0] as ExplorationExitData
			if first.requires_clear or not first.required_action.is_empty() or not first.required_claims.is_empty():
				_fail(region,first,"Primary return route must be unconditional")
				break
			if not regions.has(first.target): break # Dangling target is reported by content validation.
			current=regions[first.target]
static func _fail(region: ExplorationRegionData,passage: ExplorationExitData,message: String) -> void:
	region.map_errors.append(str(passage.get_meta("map_source",region.id))+": "+message)
