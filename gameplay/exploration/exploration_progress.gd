class_name ExplorationProgress
extends RefCounted

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
	return {"actions": actions.duplicate(), "spell_rules": spell_rules.duplicate(), "claims": claims.duplicate(), "cleared": cleared.duplicate(), "journal": journal.duplicate(true), "completed": completed, "deaths": deaths, "world_states": world_states.duplicate(true), "loadout": loadout.duplicate(true), "character_state": character_state.duplicate(true), "visited": visited.duplicate(), "choices": choices.duplicate(), "casting_supplies": casting_supplies.duplicate(true)}

func validate_save_data(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not value.get("completed", false) is bool or not value.get("deaths", 0) is int:
		return false
	for key in ["actions", "spell_rules", "recipes", "claims", "cleared", "world_states", "loadout", "character_state", "visited", "choices", "casting_supplies"]:
		if not value.get(key, {}) is Dictionary:
			return false
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
	return true

func deserialize_save_data(data: Dictionary) -> void:
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
