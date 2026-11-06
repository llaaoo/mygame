class_name SaveRepository
extends RefCounted
## Owns file validation, migration and replacement. Never restores gameplay state.

const VERSION := 4
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
	for key in ["meta", "player", "world", "quest"]:
		if not data.get(key) is Dictionary:
			return false
	if not data.get("extensions", {}) is Dictionary:
		return false
	for section in section_validators:
		if data.get("extensions", {}).has(section) and not section_validators[section].call(data.extensions[section]):
			return false
	var player: Dictionary = data.player
	for key in ["position", "skill_cooldowns", "skill_upgrade_state", "mastery_state"]:
		if not player.get(key, {}) is Dictionary:
			return false
	for key in ["inventory_items", "equipment_items", "skill_slots", "buff_state"]:
		if not player.get(key, []) is Array:
			return false
	return data.world.get("object_states", {}) is Dictionary and data.quest.get("active", []) is Array and data.quest.get("completed", []) is Array

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
