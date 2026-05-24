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


func tick(delta: float) -> bool:
	if _npc.global_position.distance_to(_target_pos) < 10.0:
		queue_free()
		return true

	var dir := _npc.global_position.direction_to(_target_pos)

	# 只有 NavigationAgent 返回有效路径点（非自身位置）时才使用
	if _agent.get_navigation_map().is_valid() and not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		# 无 navmesh 时 get_next_path_position 返回自身位置 → 退化为直线移动
		if next.distance_squared_to(_npc.global_position) > 1.0:
			dir = _npc.global_position.direction_to(next)

	_npc.position += dir * _speed * delta
	return false
