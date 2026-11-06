class_name ExplorationProgress
extends RefCounted

var condition_query: ConditionQuery
var foundation: Dictionary={}
var tracked_quest := ""
var waypoint: Dictionary = {}
var story_actors: Dictionary = {}
var journey: Dictionary = {}
var trial_runs: Array[Dictionary] = []
var element_clues: Dictionary = {}
var verified_reactions: Dictionary = {}
var equipment_owned: Dictionary = {}
var equipment_counts: Dictionary = {}
var loot_records: Dictionary = {}
var equipment_loadout: Dictionary = {}
var actions: Dictionary = {"ignite": true}
var spell_rules: Dictionary = {}
var claims: Dictionary = {}
var cleared: Dictionary = {}
var journal: Array[Dictionary] = []
var completed := false
var deaths := 0
var world_states: Dictionary = {}
var loadout: Dictionary = {}
var character_state: Dictionary = {}
var visited: Dictionary = {}
var choices: Dictionary = {}
var casting_supplies: Dictionary = {}
var survival_state: Dictionary = {}

func claim(id: String, title: String, text: String, new_actions: Array, new_spell_rules: Array) -> bool:
	if claims.has(id):
		return false
	claims[id] = true
	for action in new_actions:
		actions[str(action)] = true
	for rule in new_spell_rules:
		spell_rules[str(rule)] = true
	journal.append({"id": id, "title": title, "text": text})
	return true

func serialize_save_data() -> Dictionary:
	return {"foundation":foundation.duplicate(true),"tracked_quest": tracked_quest, "waypoint": waypoint.duplicate(true), "story_actors": story_actors.duplicate(true), "equipment_counts": equipment_counts.duplicate(), "loot_records": loot_records.duplicate(true), "journey": journey.duplicate(true), "survival_state": survival_state.duplicate(true), "trial_runs": trial_runs.duplicate(true), "element_clues": element_clues.duplicate(), "verified_reactions": verified_reactions.duplicate(), "equipment_owned": equipment_owned.duplicate(), "equipment_loadout": equipment_loadout.duplicate(), "actions": actions.duplicate(), "spell_rules": spell_rules.duplicate(), "claims": claims.duplicate(), "cleared": cleared.duplicate(), "journal": journal.duplicate(true), "completed": completed, "deaths": deaths, "world_states": world_states.duplicate(true), "loadout": loadout.duplicate(true), "character_state": character_state.duplicate(true), "visited": visited.duplicate(), "choices": choices.duplicate(), "casting_supplies": casting_supplies.duplicate(true)}

func validate_save_data(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not CampaignSession.valid_snapshot(value.get("foundation",{})): return false
	if condition_query and condition_query.items:
		if value.get("foundation",{}).has("inventory") and not condition_query.items.valid_definitions(value.foundation.inventory): return false
	if not LootSchema.valid_records(value.get("loot_records", {})): return false
	if condition_query and not condition_query.regions.is_empty():
		for record in value.get("loot_records",{}).values():
			if not condition_query.regions.has(record.region): return false
		for record in value.get("foundation",{}).get("actors",{}).values():
			if not condition_query.regions.has(record.region): return false
		for container in value.get("foundation",{}).get("inventory",{}).get("containers",{}).values():
			if not container.attached and not condition_query.regions.has(container.region): return false
	var counts = value.get("equipment_counts", {})
	if not counts is Dictionary: return false
	for id in counts:
		if not id is String or not counts[id] is int or counts[id] < 0 or counts[id] > 999: return false
	if not value.get("tracked_quest", "") is String: return false
	var mark = value.get("waypoint", {})
	if not mark is Dictionary: return false
	if not mark.is_empty():
		if not mark.get("position") is Array or mark.position.size()!=2: return false
		for n in mark.position:
			if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or absf(float(n))>100000: return false
	if not CampaignSnapshotSchema.valid_legacy_actors(value.get("story_actors", {})): return false
	var location = value.get("journey", {})
	if not location is Dictionary: return false
	if not location.is_empty():
		if not location.get("region") is String or not location.get("position") is Array or location.position.size() != 2: return false
		for coordinate in location.position:
			if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)) or absf(float(coordinate)) > 100000: return false
	if not SurvivalNeeds.valid(value.get("survival_state", {})): return false
	if not value.get("completed", false) is bool or not value.get("deaths", 0) is int:
		return false
	for key in ["actions", "spell_rules", "recipes", "claims", "cleared", "world_states", "loadout", "character_state", "visited", "choices", "casting_supplies", "equipment_owned", "equipment_loadout", "element_clues", "verified_reactions"]:
		if not value.get(key, {}) is Dictionary:
			return false
	if not value.get("trial_runs", []) is Array: return false
	for run in value.get("trial_runs", []):
		if not run is Dictionary or not run.get("label") is String or not run.get("result") is String: return false
		if typeof(run.get("seconds")) not in [TYPE_INT, TYPE_FLOAT] or (not is_finite(float(run.seconds)) or float(run.seconds) < 0): return false
		for key in ["casts", "melee", "damage_dealt", "damage_taken", "mana_spent"]:
			if not run.get(key) is int or int(run[key]) < 0: return false
		if not run.get("work_actions", 0) is int or int(run.get("work_actions", 0)) < 0: return false
		if not run.get("materials") is Dictionary or not run.get("regions") is Array or not run.get("initial") is Dictionary or not run.get("final") is Dictionary: return false
		for counter in ["work_attempts", "work_interruptions"]:
			if not run.get(counter, {}) is Dictionary: return false
			for amount in run.get(counter, {}).values():
				if not amount is int or amount < 0: return false
		if not run.get("recovery", {}) is Dictionary: return false
		for resource in run.get("recovery", {}).values():
			if not resource is Dictionary: return false
			for amount in resource.values():
				if typeof(amount) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(amount)) or amount < 0: return false
		for key in ["cast_steps", "surface_steps"]:
			if not run.get(key, []) is Array or run.get(key, []).size() > 128: return false
			for step in run.get(key, []):
				if not step is Dictionary: return false
		for snapshot in [run.initial, run.final]:
			if not SurvivalNeeds.valid(snapshot.get("survival", {})): return false
			if not snapshot.get("equipment", []) is Array: return false
			for item in snapshot.get("equipment", []):
				if not item is String: return false
			for key in ["stats", "loadout", "supplies"]:
				if not snapshot.get(key, {}) is Dictionary: return false
			for key in ["max_hp", "max_mp"]:
				if typeof(snapshot.get(key, 0)) not in [TYPE_INT, TYPE_FLOAT]: return false
			for value_stat in snapshot.get("stats", {}).values():
				if typeof(value_stat) not in [TYPE_INT, TYPE_FLOAT]: return false
			var amounts: Variant = snapshot.get("supplies", {}).get("amounts", {})
			if not amounts is Dictionary: return false
			for id in amounts:
				if not id is String or not amounts[id] is int or int(amounts[id]) < 0: return false

		for region in run.regions:
			if not region is String: return false
		for id in run.materials:
			if not id is String or not run.materials[id] is int or int(run.materials[id]) < 0: return false
	if not value.get("journal", []) is Array:
		return false
	for entry in value.get("journal", []):
		if not entry is Dictionary:
			return false
		for key in ["id", "title", "text"]:
			if not entry.get(key) is String:
				return false
	var supplies: Dictionary = value.get("casting_supplies", {})
	var character: Dictionary = value.get("character_state", {})
	if not supplies.get("amounts", {}) is Dictionary or not supplies.get("selected", {}) is Dictionary or not character.get("stats", {}) is Dictionary or not character.get("mastery", {}) is Dictionary:
		return false
	for numbers: Dictionary in [supplies.get("amounts", {}), character.get("stats", {})]:
		for number in numbers.values():
			if typeof(number) not in [TYPE_INT, TYPE_FLOAT]:
				return false
	for selection in supplies.get("selected", {}).values():
		if not selection is String:
			return false
	for entry in value.get("loadout", {}).values():
		if not entry is Dictionary or not entry.get("skill_id", "") is String or not entry.get("upgrades", {}) is Dictionary:
			return false
		for rank in entry.get("upgrades", {}).values():
			if typeof(rank) not in [TYPE_INT, TYPE_FLOAT]:
				return false
	for key in ["element_clues", "verified_reactions"]:
		for id in value.get(key, {}):
			if not id is String or not value[key][id] is bool: return false
	for id in value.get("equipment_owned", {}):
		if not id is String or not value.equipment_owned[id] is bool:
			return false
	for slot in value.get("equipment_loadout", {}):
		if not slot is String or not value.equipment_loadout[slot] is String:
			return false
	return true

func deserialize_save_data(data: Dictionary) -> void:
	foundation=data.get("foundation",{}).duplicate(true)
	tracked_quest = data.get("tracked_quest", "")
	waypoint = data.get("waypoint", {}).duplicate(true)
	story_actors = data.get("story_actors", {}).duplicate(true)
	journey = data.get("journey", {}).duplicate(true)
	survival_state = data.get("survival_state", {}).duplicate(true)
	trial_runs.assign(data.get("trial_runs", []))
	while trial_runs.size() > 10: trial_runs.pop_front()
	element_clues = data.get("element_clues", {}).duplicate()
	# Old frost knowledge belongs to water; learned actions/reactions keep their IDs.
	if element_clues.get("ice", false): element_clues["water"] = true
	element_clues.erase("ice")
	verified_reactions = data.get("verified_reactions", {}).duplicate()
	loot_records = data.get("loot_records", {}).duplicate(true)
	equipment_counts = data.get("equipment_counts", {}).duplicate()
	equipment_owned = data.get("equipment_owned", {}).duplicate()
	for id in equipment_owned:
		if equipment_owned[id] and not equipment_counts.has(id): equipment_counts[id] = 1
	equipment_loadout = data.get("equipment_loadout", {}).duplicate()
	actions = data.get("actions", {"ignite": true}).duplicate()
	actions["ignite"] = true
	spell_rules = data.get("spell_rules", data.get("recipes", {})).duplicate()
	claims = data.get("claims", {}).duplicate()
	cleared = data.get("cleared", {}).duplicate()
	journal.clear()
	for entry in data.get("journal", []):
		if entry is Dictionary:
			journal.append(entry.duplicate(true))
	completed = bool(data.get("completed", false))
	deaths = maxi(0, int(data.get("deaths", 0)))
	world_states = data.get("world_states", {}).duplicate(true)
	loadout = data.get("loadout", {}).duplicate(true)
	character_state = data.get("character_state", {}).duplicate(true)
	visited = data.get("visited", {}).duplicate()
	for id in cleared:
		visited[id] = true
	choices = data.get("choices", {}).duplicate()
	casting_supplies = data.get("casting_supplies", {}).duplicate(true)
