class_name SaveData
extends RefCounted


static func _string_array(raw: Array) -> Array[String]:
	var out: Array[String] = []
	for value in raw:
		out.append(str(value))
	return out


class MetaData:
	var version: int = 1
	var timestamp: int = 0
	var play_time: float = 0.0
	var player_level: int = 1
	var region_id: String = ""

	func serialize() -> Dictionary:
		return {
			"version": version,
			"timestamp": timestamp,
			"play_time": play_time,
			"player_level": player_level,
			"region_id": region_id,
		}

	static func deserialize(data: Dictionary) -> MetaData:
		var meta := MetaData.new()
		meta.version = data.get("version", 1)
		meta.timestamp = data.get("timestamp", 0)
		meta.play_time = data.get("play_time", 0.0)
		meta.player_level = data.get("player_level", 1)
		meta.region_id = data.get("region_id", "")
		return meta


class PlayerData:
	var position: Vector2 = Vector2.ZERO
	var hp: int = 100
	var max_hp: int = 100
	var mp: int = 50
	var max_mp: int = 50
	var level: int = 1
	var experience: int = 0
	var exp_to_next: int = 100
	var attribute_points: int = 0
	var strength: int = 10
	var intelligence: int = 10
	var agility: int = 10
	var endurance: int = 10
	var inventory_items: Array[Dictionary] = []
	var skill_left: String = ""
	var skill_right: String = ""
	var skill_slots: Array[String] = []
	var skill_cooldowns: Dictionary = {}
	var mastery_state: Dictionary = {}
	var buff_state: Array[Dictionary] = []

	func serialize() -> Dictionary:
		return {
			"position": {"x": position.x, "y": position.y},
			"hp": hp,
			"max_hp": max_hp,
			"mp": mp,
			"max_mp": max_mp,
			"level": level,
			"experience": experience,
			"exp_to_next": exp_to_next,
			"attribute_points": attribute_points,
			"strength": strength,
			"intelligence": intelligence,
			"agility": agility,
			"endurance": endurance,
			"inventory_items": inventory_items,
			"skill_left": skill_left,
			"skill_right": skill_right,
			"skill_slots": skill_slots,
			"skill_cooldowns": skill_cooldowns,
			"mastery_state": mastery_state,
			"buff_state": buff_state,
		}

	static func deserialize(data: Dictionary) -> PlayerData:
		var player := PlayerData.new()
		var pos: Dictionary = data.get("position", {})
		player.position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
		player.hp = data.get("hp", 100)
		player.max_hp = data.get("max_hp", 100)
		player.mp = data.get("mp", 50)
		player.max_mp = data.get("max_mp", 50)
		player.level = data.get("level", 1)
		player.experience = data.get("experience", 0)
		player.exp_to_next = data.get("exp_to_next", 100)
		player.attribute_points = data.get("attribute_points", 0)
		player.strength = data.get("strength", 10)
		player.intelligence = data.get("intelligence", 10)
		player.agility = data.get("agility", 10)
		player.endurance = data.get("endurance", 10)
		player.inventory_items = data.get("inventory_items", []) as Array[Dictionary]
		player.skill_left = data.get("skill_left", "")
		player.skill_right = data.get("skill_right", "")
		player.skill_slots = SaveData._string_array(data.get("skill_slots", []))
		player.skill_cooldowns = data.get("skill_cooldowns", {})
		player.mastery_state = data.get("mastery_state", {})
		player.buff_state = data.get("buff_state", []) as Array[Dictionary]
		return player


class WorldData:
	var object_states: Dictionary = {}
	var world_time_hour: float = 8.0

	func serialize() -> Dictionary:
		return {
			"object_states": object_states,
			"world_time_hour": world_time_hour,
		}

	static func deserialize(data: Dictionary) -> WorldData:
		var world := WorldData.new()
		world.object_states = data.get("object_states", {})
		world.world_time_hour = data.get("world_time_hour", 8.0)
		return world


class QuestSave:
	var completed: Array[String] = []
	var active: Array[Dictionary] = []

	func serialize() -> Dictionary:
		return {
			"completed": completed,
			"active": active,
		}

	static func deserialize(data: Dictionary) -> QuestSave:
		var quest := QuestSave.new()
		quest.completed = SaveData._string_array(data.get("completed", []))
		quest.active = data.get("active", []) as Array[Dictionary]
		return quest


class Root:
	var meta: MetaData
	var player: PlayerData
	var world: WorldData
	var quest: QuestSave

	func serialize() -> Dictionary:
		return {
			"version": 1,
			"meta": meta.serialize(),
			"player": player.serialize(),
			"world": world.serialize(),
			"quest": quest.serialize(),
		}

	static func deserialize(data: Dictionary) -> Root:
		var root := Root.new()
		root.meta = MetaData.deserialize(data.get("meta", {}))
		root.player = PlayerData.deserialize(data.get("player", {}))
		root.world = WorldData.deserialize(data.get("world", {}))
		root.quest = QuestSave.deserialize(data.get("quest", {}))
		return root
