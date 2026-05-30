class_name RegionRuntime
extends Node

signal region_changed(region_path: String)

const _PERSISTENT_ROOT_CHILDREN := {
	"Player": true,
	"HUDLayer": true,
	"InputSetup": true,
	"GameRuntime": true,
}

var _current_region_path: String = ""


func _ready() -> void:
	call_deferred("_capture_initial_region")


func get_current_region() -> Node:
	var root := get_tree().current_scene
	if not root:
		return null
	for child in root.get_children():
		if child is Node2D and not _PERSISTENT_ROOT_CHILDREN.has(child.name):
			return child
	return null


func get_current_region_path() -> String:
	if not _current_region_path.is_empty():
		return _current_region_path
	var region := get_current_region()
	return region.scene_file_path if region else ""


func ensure_region(region_path: String, spawn_marker_id: String = "") -> bool:
	if region_path.is_empty():
		return false

	var current := get_current_region()
	if current and current.scene_file_path == region_path:
		_current_region_path = region_path
		await get_tree().process_frame
		_place_player(spawn_marker_id)
		return true

	var packed := load(region_path) as PackedScene
	if not packed:
		push_error("RegionRuntime: failed to load %s" % region_path)
		return false

	var root := get_tree().current_scene
	if not root:
		return false

	var world_runtime := GameRuntime.instance.get_world_runtime() if GameRuntime.instance else null
	if world_runtime:
		world_runtime.prepare_region_swap()

	MarkerRegistry.clear()

	if current:
		root.remove_child(current)
		current.queue_free()

	var new_region := packed.instantiate()
	root.add_child(new_region)
	await get_tree().process_frame

	_current_region_path = new_region.scene_file_path if not new_region.scene_file_path.is_empty() else region_path
	_place_player(spawn_marker_id)
	region_changed.emit(_current_region_path)
	return true


func _capture_initial_region() -> void:
	var region := get_current_region()
	if region:
		_current_region_path = region.scene_file_path


func _place_player(spawn_marker_id: String) -> void:
	if spawn_marker_id.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	if MarkerRegistry.has(spawn_marker_id):
		player.global_position = MarkerRegistry.get_position(spawn_marker_id)
	else:
		push_warning("RegionRuntime: missing spawn marker '%s'" % spawn_marker_id)
