class_name ExplorationProgress
extends SaveRecord

var condition_query: ConditionQuery
var foundation_status: Callable
@export_storage var foundation: Dictionary={}
@export_storage var tracked_quest := ""
@export_storage var waypoint: Dictionary = {}
@export_storage var story_actors: Dictionary = {}
@export_storage var journey: Dictionary = {}
@export_storage var trial_runs: Array[Dictionary] = []
@export_storage var element_clues: Dictionary = {}
@export_storage var verified_reactions: Dictionary = {}
@export_storage var equipment_owned: Dictionary = {}
@export_storage var equipment_counts: Dictionary = {}
@export_storage var loot_records: Dictionary = {}
@export_storage var equipment_loadout: Dictionary = {}
@export_storage var actions: Dictionary = {"ignite": true}
@export_storage var spell_rules: Dictionary = {}
@export_storage var claims: Dictionary = {}
@export_storage var cleared: Dictionary = {}
@export_storage var journal: Array[Dictionary] = []
@export_storage var completed := false
@export_storage var deaths := 0
@export_storage var world_states: Dictionary = {}
@export_storage var loadout: Dictionary = {}
@export_storage var character_state: Dictionary = {}
@export_storage var visited: Dictionary = {}
@export_storage var choices: Dictionary = {}
@export_storage var casting_supplies: Dictionary = {}
@export_storage var survival_state: Dictionary = {}

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

func save_read_status(value: Dictionary) -> int:
	return int(foundation_status.call(value.get("foundation",{}))) if foundation_status.is_valid() else SaveSections.Status.VALID

func validate_save_data(value: Variant) -> bool:
	if not super.validate_save_data(value):
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
		if not mark.get("region","camp") is String: return false
		if condition_query and not condition_query.regions.is_empty() and not condition_query.regions.has(mark.get("region","camp")): return false
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
	if not StatsComponent.valid_progression(character.get("stats",{})): return false
	if not SkillMasteryManager.valid_state(character.get("mastery",{}),int(character.get("stats",{}).get("level",1))): return false
	for numbers: Dictionary in [supplies.get("amounts", {}), character.get("stats", {})]:
		for number in numbers.values():
			if typeof(number) not in [TYPE_INT, TYPE_FLOAT]:
				return false
	for selection in supplies.get("selected", {}).values():
		if not selection is String:
			return false
	for source in value.get("loadout",{}):
		if source not in QuickslotLoadout.SOURCES and source!="__configured": return false
		if not QuickslotLoadout.valid_entry(value.loadout[source]): return false
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
	var migrated:=data.duplicate(true)
	if not migrated.has("spell_rules") and migrated.has("recipes"): migrated["spell_rules"]=migrated.recipes
	migrated.erase("recipes")
	if not SaveFields.valid(self,migrated): return
	super.deserialize_save_data(migrated)
	while trial_runs.size()>10: trial_runs.pop_front()
	# Semantic compatibility belongs here, not in the file-format migration ladder.
	if element_clues.get("ice",false): element_clues["water"]=true
	element_clues.erase("ice")
	for id in equipment_owned:
		if equipment_owned[id] and not equipment_counts.has(id): equipment_counts[id]=1
	actions["ignite"]=true
	deaths=maxi(0,deaths)
	for id in cleared: visited[id]=true
