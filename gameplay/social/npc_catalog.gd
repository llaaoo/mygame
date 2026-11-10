class_name NpcCatalog
extends Resource
@export var profiles: Array[NpcProfile]=[]
static var _default: NpcCatalog
static func default_catalog() -> NpcCatalog:
	if not _default: _default=load("res://content/social/catalog.tres") as NpcCatalog
	return _default
func profile(id: String) -> NpcProfile:
	for entry in profiles:
		if entry.actor_id==id: return entry
	return null
func validation_errors(world: ExplorationContentCatalog=null,extra_facts: Dictionary={}) -> Array[String]:
	var errors: Array[String]=[]; var seen: Dictionary={}
	for entry in profiles:
		if not entry or seen.has(entry.actor_id): errors.append("Missing/duplicate NPC"); continue
		seen[entry.actor_id]=true; errors.append_array(entry.validation_errors())
		if world:
			if not world.regions.has(entry.region_id): errors.append("Unknown NPC region: "+entry.actor_id)
			for topic in entry.topics:
				if not topic: continue
				if not topic.successor_actor_id.is_empty() and (topic.successor_actor_id==entry.actor_id or not profile(topic.successor_actor_id)):errors.append("Invalid favor successor: "+topic.id)
				for claim in topic.required_claims:
					if world.fact(claim).is_empty() and not extra_facts.has(claim) and not world.chapter.quests.any(func(quest: ExplorationQuestData): return "quest."+quest.id==claim): errors.append("Unknown NPC prerequisite: "+claim)
				for hint in topic.navigation_hints:
					if not hint or hint.target_region.is_empty()==hint.target_claim.is_empty(): errors.append("NPC lead requires exactly one target"); continue
					if not hint.target_region.is_empty() and not world.regions.has(hint.target_region): errors.append("Unknown NPC lead region: "+hint.target_region)
					if not hint.target_claim.is_empty() and world.fact(hint.target_claim).is_empty(): errors.append("Unknown NPC lead fact: "+hint.target_claim)
	return errors
