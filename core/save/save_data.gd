class_name SaveData
extends RefCounted
## SaveData — 存档数据结构容器


static func _string_array(raw: Array) -> Array[String]:
	var out: Array[String] = []
	for v in raw:
		out.append(str(v))
	return out


## ── Meta ──

class MetaData:
	var version: int = 1
	var timestamp: int = 0        ## Time.get_unix_time_from_system()
	var play_time: float = 0.0
	var player_level: int = 1
	var region_id: String = ""

	func serialize() -> Dictionary:
		return {
			"version": version, "timestamp": timestamp,
			"play_time": play_time, "player_level": player_level,
			"region_id": region_id,
		}

	static func deserialize(d: Dictionary) -> MetaData:
		var m := MetaData.new()
		m.version = d.get("version", 1)
		m.timestamp = d.get("timestamp", 0)
		m.play_time = d.get("play_time", 0.0)
		m.player_level = d.get("player_level", 1)
		m.region_id = d.get("region_id", "")
		return m


## ── Player ──

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

	var inventory_items: Array[Dictionary] = []   ## [{path, quantity, slot}]
	var skill_left: String = ""
	var skill_right: String = ""
	var skill_slots: Array[String] = []
	var skill_cooldowns: Dictionary = {}  ## {source: remaining}

	func serialize() -> Dictionary:
		return {
			"position": {"x": position.x, "y": position.y},
			"hp": hp, "max_hp": max_hp, "mp": mp, "max_mp": max_mp,
			"level": level, "experience": experience, "exp_to_next": exp_to_next,
			"attribute_points": attribute_points,
			"strength": strength, "intelligence": intelligence,
			"agility": agility, "endurance": endurance,
			"inventory_items": inventory_items,
			"skill_left": skill_left, "skill_right": skill_right,
			"skill_slots": skill_slots,
			"skill_cooldowns": skill_cooldowns,
		}

	static func deserialize(d: Dictionary) -> PlayerData:
		var p := PlayerData.new()
		var pos: Dictionary = d.get("position", {})
		p.position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
		p.hp = d.get("hp", 100); p.max_hp = d.get("max_hp", 100)
		p.mp = d.get("mp", 50); p.max_mp = d.get("max_mp", 50)
		p.level = d.get("level", 1); p.experience = d.get("experience", 0)
		p.exp_to_next = d.get("exp_to_next", 100)
		p.attribute_points = d.get("attribute_points", 0)
		p.strength = d.get("strength", 10); p.intelligence = d.get("intelligence", 10)
		p.agility = d.get("agility", 10); p.endurance = d.get("endurance", 10)
		p.inventory_items = d.get("inventory_items", []) as Array[Dictionary]
		p.skill_left = d.get("skill_left", ""); p.skill_right = d.get("skill_right", "")
		p.skill_slots = SaveData._string_array(d.get("skill_slots", []))
		p.skill_cooldowns = d.get("skill_cooldowns", {})
		return p


## ── World ──

class WorldData:
	var object_states: Dictionary = {}
	var world_time_hour: float = 8.0

	func serialize() -> Dictionary:
		return {"object_states": object_states, "world_time_hour": world_time_hour}

	static func deserialize(d: Dictionary) -> WorldData:
		var w := WorldData.new()
		w.object_states = d.get("object_states", {})
		w.world_time_hour = d.get("world_time_hour", 8.0)
		return w


## ── Quest ──

class QuestSave:
	var completed: Array[String] = []
	var active: Array[Dictionary] = []

	func serialize() -> Dictionary:
		return {"completed": completed, "active": active}

	static func deserialize(d: Dictionary) -> QuestSave:
		var q := QuestSave.new()
		q.completed = SaveData._string_array(d.get("completed", []))
		q.active = d.get("active", []) as Array[Dictionary]
		return q


## ── Root ──

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

	static func deserialize(d: Dictionary) -> Root:
		var r := Root.new()
		r.meta = MetaData.deserialize(d.get("meta", {}))
		r.player = PlayerData.deserialize(d.get("player", {}))
		r.world = WorldData.deserialize(d.get("world", {}))
		r.quest = QuestSave.deserialize(d.get("quest", {}))
		return r
