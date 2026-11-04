class_name ExplorationProgress
extends RefCounted

var actions: Dictionary = {"ignite": true}
var recipes: Dictionary = {}
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

func claim(id: String, title: String, text: String, new_actions: Array, new_recipes: Array) -> bool:
	if claims.has(id):
		return false
	claims[id] = true
	for action in new_actions:
		actions[str(action)] = true
	for recipe in new_recipes:
		recipes[str(recipe)] = true
	journal.append({"id": id, "title": title, "text": text})
	return true

func serialize_save_data() -> Dictionary:
	return {"actions": actions.duplicate(), "recipes": recipes.duplicate(), "claims": claims.duplicate(), "cleared": cleared.duplicate(), "journal": journal.duplicate(true), "completed": completed, "deaths": deaths, "world_states": world_states.duplicate(true), "loadout": loadout.duplicate(true), "character_state": character_state.duplicate(true), "visited": visited.duplicate(), "choices": choices.duplicate(), "casting_supplies": casting_supplies.duplicate(true)}

func deserialize_save_data(data: Dictionary) -> void:
	actions = data.get("actions", {"ignite": true}).duplicate()
	actions["ignite"] = true
	recipes = data.get("recipes", {}).duplicate()
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
