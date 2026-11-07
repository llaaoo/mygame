class_name SaveRepository
extends RefCounted
## Owns file validation, migration and replacement. Never restores gameplay state.

const VERSION := 7
enum Status { MISSING, VALID, RECOVERED, INVALID, UNSUPPORTED_VERSION, IO_ERROR }
var section_validators: Dictionary = {}

class ReadResult extends RefCounted:
	var status: Status
	var data: Dictionary
	func _init(value: Status, payload: Dictionary = {}) -> void:
		status = value
		data = payload
	func usable() -> bool:
		return status in [Status.VALID, Status.RECOVERED]

func read(path: String) -> ReadResult:
	var primary := _read_file(path)
	# A newer primary must not be silently downgraded to an older backup.
	if primary.status in [Status.VALID, Status.UNSUPPORTED_VERSION]:
		return primary
	var backup := _read_file(path + ".bak")
	if backup.status == Status.VALID:
		return ReadResult.new(Status.RECOVERED, backup.data)
	if backup.status == Status.UNSUPPORTED_VERSION:
		return backup
	if primary.status == Status.MISSING and backup.status == Status.MISSING:
		return primary
	return ReadResult.new(Status.IO_ERROR if primary.status == Status.IO_ERROR or backup.status == Status.IO_ERROR else Status.INVALID)

func write(path: String, data: Dictionary) -> bool:
	if not _valid_shape(data) or int(data.get("version", 0)) != VERSION:
		return false
	var existing := read(path)
	if not existing.usable() and existing.status != Status.MISSING:
		return false # Preserve unreadable/unsupported files until they can be recovered.
	if _read_file(path + ".bak").status == Status.UNSUPPORTED_VERSION:
		return false
	if _write_file(path + ".tmp", data) != OK:
		return false
	if existing.status == Status.VALID:
		# Replace the backup only after a complete copy; never back up a corrupt primary.
		if _copy_file(path, path + ".bak.tmp") != OK or _replace_file(path + ".bak.tmp", path + ".bak") != OK:
			return false
	return _replace_file(path + ".tmp", path) == OK

func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	if not data.get("version", 1) is int:
		return {}
	var version := int(data.get("version", 1))
	if version < 1 or version > VERSION:
		return {}
	while version < VERSION:
		match version:
			1:
				data["extensions"] = data.get("extensions", {})
			2:
				if not data.get("player", {}) is Dictionary:
					return {}
				var player_data: Dictionary = data.get("player", {})
				player_data["equipment_items"] = player_data.get("equipment_items", [])
				data["player"] = player_data
			3:
				# v4 adds optional authoritative campaign snapshots; old fields remain valid migration input.
				data["extensions"]=data.get("extensions",{})
			4:
				# Operation IDs and new item definitions require the v5 content reader.
				data["extensions"]=data.get("extensions",{})
			5:
				# Stateful consumable instances and item actions require the v6 reader.
				data["extensions"]=data.get("extensions",{})
			6:
				# v7 stores mixed quickslot bindings; legacy belt import happens at actor binding.
				data["extensions"]=data.get("extensions",{})
		version += 1
		data["version"] = version
	return data

func _read_file(path: String) -> ReadResult:
	if not FileAccess.file_exists(path):
		return ReadResult.new(Status.MISSING)
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ReadResult.new(Status.IO_ERROR)
	# store_var writes a 32-bit length prefix. Reject truncated envelopes before decoding.
	if file.get_length() < 4:
		return ReadResult.new(Status.INVALID)
	var size := file.get_32()
	if size < 4 or size != file.get_length() - 4:
		return ReadResult.new(Status.INVALID)
	file.seek(0)
	var raw: Variant = file.get_var(false)
	file.close()
	if not raw is Dictionary:
		return ReadResult.new(Status.INVALID)
	if not raw.get("version", 1) is int:
		return ReadResult.new(Status.INVALID)
	if int(raw.get("version", 1)) > VERSION:
		return ReadResult.new(Status.UNSUPPORTED_VERSION)
	if not _valid_shape(raw):
		return ReadResult.new(Status.INVALID)
	var data := migrate(raw)
	return ReadResult.new(Status.VALID, data) if not data.is_empty() else ReadResult.new(Status.INVALID)

func _valid_shape(data: Dictionary) -> bool:
	if not data.get("version", 1) is int:
		return false
	for key in ["meta", "player", "world", "quest", "extensions"]:
		if not data.get(key, {} if key == "extensions" else null) is Dictionary:
			return false

	var extensions: Dictionary = data.get("extensions", {})
	for section in extensions:
		if not section is String or not extensions[section] is Dictionary:
			return false
		if section_validators.has(section) and not section_validators[section].call(extensions[section]):
			return false

	return (
		_valid_fields(data.meta, {
			"version": TYPE_INT, "timestamp": TYPE_INT, "play_time": TYPE_FLOAT,
			"player_level": TYPE_INT, "region_id": TYPE_STRING,
		})
		and _valid_player(data.player)
		and _valid_world(data.world)
		and _valid_quests(data.quest)
	)


func _valid_player(player: Dictionary) -> bool:
	if not _valid_fields(player, {
		"position": TYPE_DICTIONARY, "hp": TYPE_INT, "max_hp": TYPE_INT,
		"mp": TYPE_INT, "max_mp": TYPE_INT, "level": TYPE_INT, "experience": TYPE_INT,
		"exp_to_next": TYPE_INT, "attribute_points": TYPE_INT, "strength": TYPE_INT,
		"intelligence": TYPE_INT, "agility": TYPE_INT, "endurance": TYPE_INT,
		"skill_left": TYPE_STRING, "skill_right": TYPE_STRING, "skill_slots": TYPE_ARRAY,
		"skill_cooldowns": TYPE_DICTIONARY, "skill_upgrade_state": TYPE_DICTIONARY,
		"mastery_state": TYPE_DICTIONARY, "inventory_items": TYPE_ARRAY,
		"equipment_items": TYPE_ARRAY, "buff_state": TYPE_ARRAY,
	}):
		return false
	if player.get("max_hp", 100) < 1 or player.get("max_mp", 50) < 0:
		return false
	var position: Dictionary = player.get("position", {})
	if not _valid_fields(position, {"x": TYPE_FLOAT, "y": TYPE_FLOAT}):
		return false
	if not Vector2(position.get("x", 0.0), position.get("y", 0.0)).is_finite():
		return false
	if not _valid_array(player.get("skill_slots", []), TYPE_STRING):
		return false

	var cooldowns: Dictionary = player.get("skill_cooldowns", {})
	for source in cooldowns:
		if not source is String or not _valid_number(cooldowns[source]) or cooldowns[source] < 0:
			return false

	var upgrades: Dictionary = player.get("skill_upgrade_state", {})
	for source in upgrades:
		if not source is String or not upgrades[source] is Dictionary:
			return false
		var slot: Dictionary = upgrades[source]
		if not _valid_fields(slot, {"skill_id": TYPE_STRING, "upgrades": TYPE_DICTIONARY}):
			return false
		var ranks: Dictionary = slot.get("upgrades", {})
		for id in ranks:
			if not id is String or not ranks[id] is int or ranks[id] < 0:
				return false

	for item in player.get("inventory_items", []):
		if not item is Dictionary or not item.has_all(["path", "slot", "quantity"]):
			return false
		if not _valid_fields(item, {"path": TYPE_STRING, "slot": TYPE_INT, "quantity": TYPE_INT}):
			return false
		if item.slot < 0 or item.quantity < 1:
			return false

	for item in player.get("equipment_items", []):
		if not item is Dictionary or not _valid_fields(item, {"path": TYPE_STRING, "slot": TYPE_INT}):
			return false

	for buff in player.get("buff_state", []):
		if not buff is Dictionary or not _valid_fields(buff, {
			"resource_path": TYPE_STRING, "runtime_id": TYPE_STRING, "duration": TYPE_FLOAT,
			"remaining": TYPE_FLOAT, "stacks": TYPE_INT, "tick_elapsed": TYPE_FLOAT,
			"source_magic": TYPE_FLOAT,
		}):
			return false
	return _valid_mastery(player.get("mastery_state", {}))


func _valid_mastery(data: Dictionary) -> bool:
	if not _valid_fields(data, {"masteries": TYPE_DICTIONARY, "unlocked_perks": TYPE_DICTIONARY}):
		return false
	var masteries: Dictionary = data.get("masteries", {})
	for school in masteries:
		if not _valid_school_key(school) or not masteries[school] is Dictionary:
			return false
		if not _valid_fields(masteries[school], {
			"level": TYPE_INT, "xp": TYPE_FLOAT, "xp_to_next": TYPE_FLOAT, "perk_points": TYPE_INT,
		}):
			return false
	var perks: Dictionary = data.get("unlocked_perks", {})
	for school in perks:
		if not _valid_school_key(school) or not _valid_array(perks[school], TYPE_STRING):
			return false
	return true


func _valid_school_key(value: Variant) -> bool:
	return value is int or (value is String and value.is_valid_int())


func _valid_world(world: Dictionary) -> bool:
	if not _valid_fields(world, {"object_states": TYPE_DICTIONARY, "world_time_hour": TYPE_FLOAT}):
		return false
	var states: Dictionary = world.get("object_states", {})
	for id in states:
		if not id is String or not states[id] is Dictionary:
			return false
		if not _valid_fields(states[id], {
			"state": TYPE_STRING, "hp": TYPE_INT, "max_hp": TYPE_INT, "respawn_at": TYPE_FLOAT,
		}):
			return false
	return true


func _valid_quests(quest: Dictionary) -> bool:
	if not _valid_fields(quest, {"active": TYPE_ARRAY, "completed": TYPE_ARRAY}):
		return false
	if not _valid_array(quest.get("completed", []), TYPE_STRING):
		return false
	for entry in quest.get("active", []):
		if not entry is Dictionary or not _valid_fields(entry, {
			"resource_path": TYPE_STRING, "quest_id": TYPE_STRING,
			"stage": TYPE_INT, "progress": TYPE_ARRAY,
		}):
			return false
		if not _valid_array(entry.get("progress", []), TYPE_INT):
			return false
	return true


func _valid_fields(data: Dictionary, types: Dictionary) -> bool:
	for key in types:
		if not data.has(key):
			continue # Older versions omit optional fields, so readers apply their defaults.
		if types[key] == TYPE_FLOAT:
			if not _valid_number(data[key]):
				return false
		elif typeof(data[key]) != types[key]:
			return false
	return true


func _valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _valid_array(data: Variant, element_type: int) -> bool:
	if not data is Array:
		return false
	for value in data:
		if typeof(value) != element_type:
			return false
	return true


func _write_file(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_var(data, false)
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func _copy_file(source: String, destination: String) -> Error:
	return DirAccess.copy_absolute(source, destination)

func _replace_file(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(source, destination)
