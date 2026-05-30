class_name PrisonOpeningController
extends Node

@export var quest_data: QuestData
@export var prisoner_path: NodePath
@export var cell_lever_path: NodePath
@export var contraband_chest_path: NodePath
@export var exit_gate_path: NodePath
@export var guard_paths: Array[NodePath] = []
@export var required_guard_kills: int = 1

var _killed_guards: int = 0
var _chest_opened: bool = false
var _exit_unlocked: bool = false
var _bus_retry_count: int = 0


func _ready() -> void:
	call_deferred("_setup_opening_loop")


func _setup_opening_loop() -> void:
	_setup_prisoner()
	_setup_groups()
	_lock_exit()

	if not CombatEventBus.instance:
		_bus_retry_count += 1
		if _bus_retry_count < 10:
			call_deferred("_setup_opening_loop")
		return
	_bus_retry_count = 0
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_INTERACT, _on_interact)
	CombatEventBus.instance.subscribe(CombatEvent.Type.ON_KILL, _on_kill)


func _exit_tree() -> void:
	if CombatEventBus.instance:
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_INTERACT, _on_interact)
		CombatEventBus.instance.unsubscribe(CombatEvent.Type.ON_KILL, _on_kill)


func _setup_prisoner() -> void:
	var prisoner := get_node_or_null(prisoner_path) as DialogueNPC
	if prisoner == null:
		return
	prisoner.add_to_group("prisoner")
	if quest_data:
		prisoner.quest_data = quest_data
		prisoner.quest_available_lines = [
			"Keep your voice down. Pull the lever beside the bunk, then get to storage.",
			"There is a supply chest past the patrol. Take what you can and drop one guard.",
			"The lower gate will open once the patrol is thin enough."
		]
		prisoner.quest_active_lines = [
			"Lever, storage chest, then one guard. Do not waste the opening.",
		]
		prisoner.quest_completed_lines = [
			"The lower gate is open. Move before the next watch rotation.",
		]


func _setup_groups() -> void:
	var lever := get_node_or_null(cell_lever_path)
	if lever:
		lever.add_to_group("cell_lever")

	var chest := get_node_or_null(contraband_chest_path)
	if chest:
		chest.add_to_group("escape_supply")
		chest.add_to_group("chest")
		if chest.has_method("is_opened") and chest.is_opened():
			_chest_opened = true

	var exit_gate := get_node_or_null(exit_gate_path)
	if exit_gate:
		exit_gate.add_to_group("prison_exit")

	for path in guard_paths:
		var guard := get_node_or_null(path)
		if guard:
			guard.add_to_group("prison_guard")


func _lock_exit() -> void:
	var gate := get_node_or_null(exit_gate_path) as Portal
	if gate == null:
		return
	gate.target_label = "Lower Gate"
	gate.lock("Locked: find supplies and defeat a guard")


func _unlock_exit() -> void:
	if _exit_unlocked:
		return
	_exit_unlocked = true
	var gate := get_node_or_null(exit_gate_path) as Portal
	if gate:
		gate.unlock()
	print("Prison opening loop: lower gate unlocked")


func _on_interact(ev: CombatEvent) -> void:
	if ev.target == null:
		return
	if ev.target.is_in_group("escape_supply"):
		_chest_opened = true
		_try_unlock_exit()


func _on_kill(ev: CombatEvent) -> void:
	if ev.target == null:
		return
	if ev.target.is_in_group("prison_guard"):
		_killed_guards += 1
		_try_unlock_exit()


func _try_unlock_exit() -> void:
	if _exit_unlocked:
		return
	if _chest_opened and _killed_guards >= required_guard_kills:
		_unlock_exit()
