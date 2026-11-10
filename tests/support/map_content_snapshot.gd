extends RefCounted
## Gameplay budget and persistence identities, independent of map serialization format.
static func archive(region: ExplorationRegionData) -> Dictionary:
	var result: Dictionary={"bounds":[region.authored_size.x,region.authored_size.y],"notes":[],"enemies":[],"surfaces":[],"obstacles":[],"exits":[]}
	for note in region.discoveries:
		result.notes.append({"id":note.id,"position":[note.pos.x,note.pos.y],"actions":note.actions,"rules":note.spell_rules,"equipment":note.equipment,"materials":note.materials,"crafts":note.get_meta("crafting_recipes",[]),"requires_clear":note.requires_clear,"heal":note.heal})
	for foe in region.encounters:
		result.enemies.append({"id":foe.get_meta("persistent_id"),"position":[foe.pos.x,foe.pos.y],"character":foe.character.resource_path if foe.character else "","profile":foe.profile.resource_path if foe.profile else "","hp":foe.hp,"speed":foe.speed,"detection":foe.detect_range})
	for patch in region.surface_patches: result.surfaces.append({"position":[patch.pos.x,patch.pos.y],"state":patch.state,"radius":patch.radius,"duration":patch.duration})
	for obstacle in region.authored_obstacles: result.obstacles.append({"position":[obstacle.position.x,obstacle.position.y],"size":[obstacle.size.x,obstacle.size.y]})
	for passage in region.exits: result.exits.append({"position":[passage.pos.x,passage.pos.y],"target":passage.target,"arrival":[passage.arrival.x,passage.arrival.y]})
	return JSON.parse_string(JSON.stringify(result))
