class_name MoveToTask
extends Node
## 移动到 Marker 的任务 — P1 最基础的 AI 行为
##
## 优先用 NavigationAgent 寻路，无 navmesh 时直线移动


var target_marker: String = ""
var _npc: Node2D
var _agent: NavigationAgent2D
var _target_pos: Vector2
var _started: bool = false
var _speed: float = 80.0


func setup(npc: Node2D, agent: NavigationAgent2D, marker_id: String) -> void:
	_npc = npc
	_agent = agent
	target_marker = marker_id
	_target_pos = MarkerRegistry.get_position(marker_id)
	_agent.target_position = _target_pos
	_started = false
	print("🚶 %s → %s (%.0f, %.0f)" % [_npc.name, marker_id, _target_pos.x, _target_pos.y])


var _frame_count: int = 0

func tick(delta: float) -> bool:
	_frame_count += 1
	if _frame_count <= 2:
		print("🚶 tick #%d: npc_pos=%s, target=%s, dist=%.0f" % [_frame_count, _npc.global_position, _target_pos, _npc.global_position.distance_to(_target_pos)])

	if _npc.global_position.distance_to(_target_pos) < 10.0:
		queue_free()
		return true

	var dir := _npc.global_position.direction_to(_target_pos)

	# 优先用 NavigationAgent（有 navmesh 时），否则直线移动
	if not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		dir = _npc.global_position.direction_to(next)

	_npc.global_position += dir * _speed * delta
	return false
