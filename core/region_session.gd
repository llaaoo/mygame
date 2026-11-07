class_name RegionSession
extends RefCounted
## All scene adapters use the same boundary; each subsystem cleans its own state.
var runtime: GameRuntime
var generation := 1
var active_root: Node2D

func _init(owner_runtime: GameRuntime) -> void:
	runtime = owner_runtime

func adopt(root: Node2D) -> void:
	active_root = root
	root.set_meta("region_generation", generation)


func mount(root: Node2D, parent: Node) -> void:
	adopt(root)
	parent.add_child(root)

func leave(root: Node, actor: Node = null) -> void:
	if actor and actor.has_method("cancel_region_actions"):
		actor.cancel_region_actions()
	# Preserve queued world facts, then cancel transient work created by those facts.
	runtime.get_command_bus().finish_region()
	runtime.get_simulation_runtime().clear_region()
	runtime.get_world_runtime().prepare_region_swap()
	generation += 1
	if is_instance_valid(root):
		root.process_mode = Node.PROCESS_MODE_DISABLED
		if root.get_parent():
			root.get_parent().remove_child(root)
		root.queue_free()
	active_root = null

func is_current(token: int) -> bool:
	return token == generation
