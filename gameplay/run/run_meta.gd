class_name RunMeta
extends RefCounted

const SAVE_PATH := "user://roguelite_meta.save"
const MAX_STARTING_BONUS_STEPS := 8
const MAX_UPGRADE_RANK := 6

var cinders: int = 0
var total_runs: int = 0
var clears: int = 0
var best_room: int = 0
var vitality_rank: int = 0
var focus_rank: int = 0


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	cinders = maxi(0, int(parsed.get("cinders", 0)))
	total_runs = maxi(0, int(parsed.get("total_runs", 0)))
	clears = maxi(0, int(parsed.get("clears", 0)))
	best_room = maxi(0, int(parsed.get("best_room", 0)))
	vitality_rank = clampi(int(parsed.get("vitality_rank", 0)), 0, MAX_UPGRADE_RANK)
	focus_rank = clampi(int(parsed.get("focus_rank", 0)), 0, MAX_UPGRADE_RANK)


func finish_run(completed_rooms: int, cleared: bool) -> int:
	var earned := maxi(0, completed_rooms) * 2
	if cleared:
		earned += 10
		clears += 1
	total_runs += 1
	best_room = maxi(best_room, completed_rooms)
	cinders += earned
	_save_to_disk()
	return earned


func starting_health_bonus() -> int:
	return (mini(clears, MAX_STARTING_BONUS_STEPS) + vitality_rank) * 5


func starting_mana_bonus() -> int:
	return (mini(clears, MAX_STARTING_BONUS_STEPS) + focus_rank) * 3


func upgrade_cost(upgrade_id: String) -> int:
	var rank := vitality_rank if upgrade_id == "vitality" else focus_rank
	return 10 + rank * 5


func can_upgrade(upgrade_id: String) -> bool:
	var rank := vitality_rank if upgrade_id == "vitality" else focus_rank
	return rank < MAX_UPGRADE_RANK and cinders >= upgrade_cost(upgrade_id)


func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_upgrade(upgrade_id):
		return false
	var cost := upgrade_cost(upgrade_id)
	cinders -= cost
	if upgrade_id == "vitality":
		vitality_rank += 1
	else:
		focus_rank += 1
	_save_to_disk()
	return true


func _save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("[RunMeta] Failed to save roguelite progress.")
		return
	file.store_string(JSON.stringify({
		"cinders": cinders,
		"total_runs": total_runs,
		"clears": clears,
		"best_room": best_room,
		"vitality_rank": vitality_rank,
		"focus_rank": focus_rank,
	}))
