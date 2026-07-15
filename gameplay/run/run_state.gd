class_name RunState
extends RefCounted

enum Status {
	INACTIVE,
	RUNNING,
	REWARD,
	BOSS,
	CLEARED,
	FAILED,
}

var status: Status = Status.INACTIVE
var seed: int = 0
var room_index: int = 0
var completed_rooms: int = 0
var rewards_taken: Array[String] = []
var relic_ids: Array[String] = []
var active_reward_choices: Array[Dictionary] = []
var room_plan: Array[Dictionary] = []


func start(new_seed: int) -> void:
	seed = new_seed
	room_index = 0
	completed_rooms = 0
	rewards_taken.clear()
	relic_ids.clear()
	active_reward_choices.clear()
	room_plan.clear()
	status = Status.RUNNING


func advance_room() -> void:
	completed_rooms += 1
	room_index += 1
	active_reward_choices.clear()


func record_reward(reward_id: String) -> void:
	if reward_id.is_empty():
		return
	rewards_taken.append(reward_id)


func record_relic(relic_id: String) -> void:
	if relic_id.is_empty() or relic_id in relic_ids:
		return
	relic_ids.append(relic_id)
