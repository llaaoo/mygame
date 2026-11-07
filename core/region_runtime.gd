class_name RegionRuntime
extends Node
## Adapts packed map travel to the shared region lifecycle.

signal region_changed(region_path: String)

var _session: RegionSession
var _mount_parent: Node
var _player: Player
var _switching := false


func setup(session: RegionSession, mount_parent: Node, player: Player, initial_region: Node2D) -> void:
	_session = session
	_mount_parent = mount_parent
	_player = player
	if initial_region:
		_session.adopt(initial_region)
	if _player:
		_player.world_provider = get_current_region


func _exit_tree() -> void:
	if is_instance_valid(_player) and _player.world_provider == get_current_region:
		_player.world_provider = Callable()


func get_current_region() -> Node2D:
	if not _session:
		return null
	var region := _session.active_root
	if is_instance_valid(region) and region.is_inside_tree() and not region.is_queued_for_deletion():
		return region
	return null


func get_current_region_path() -> String:
	var region := get_current_region()
	return region.scene_file_path if region else ""


func ensure_region(region_path: String, spawn_marker_id: String = "") -> bool:
	if _switching or region_path.is_empty() or not _can_place_player():
		return false
	if not is_instance_valid(_mount_parent) or not _mount_parent.is_inside_tree():
		return false

	_switching = true
	var generation := _session.generation
	# Portals call from Area2D.body_entered. Change physics nodes outside that callback.
	await get_tree().process_frame
	if not is_inside_tree() or not _session.is_current(generation) or not _can_place_player():
		_switching = false
		return false

	var succeeded := _switch_region(region_path, spawn_marker_id)
	_switching = false
	return succeeded


func _can_place_player() -> bool:
	return is_instance_valid(_player) and _player.is_inside_tree() and not _player.is_queued_for_deletion()


func _switch_region(region_path: String, spawn_marker_id: String) -> bool:
	var current := get_current_region()
	var next := current
	if not current or current.scene_file_path != region_path:
		next = _instantiate_region(region_path)
		if not next:
			return false

	var marker: WorldMarker
	if not spawn_marker_id.is_empty():
		marker = MarkerRegistry.find_marker(spawn_marker_id, next)
		if not marker:
			if next != current:
				next.free()
			return false

	if next != current:
		_session.leave(current, _player)
		_session.mount(next, _mount_parent)
	if marker:
		_player.global_position = marker.global_position
	if next != current:
		region_changed.emit(next.scene_file_path)
	return true


func _instantiate_region(region_path: String) -> Node2D:
	if not ResourceLoader.exists(region_path, "PackedScene"):
		return null
	var packed := ResourceLoader.load(region_path, "PackedScene") as PackedScene
	if not packed or not packed.can_instantiate():
		return null
	var instance := packed.instantiate()
	if instance is Node2D:
		return instance
	if instance:
		instance.free()
	return null
