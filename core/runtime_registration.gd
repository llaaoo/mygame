class_name RuntimeRegistration
extends RefCounted
## Early scene children can become ready before the sibling runtime enters the tree.
## Weak pending registrations are drained once by the runtime readiness boundary.
static var _waiting: Dictionary = {}

static func register_ticker(node: Node) -> void:
	var runtime := GameRuntime.instance
	if runtime and runtime.get_simulation_runtime():
		runtime.get_simulation_runtime().register_ticker(node)
	else:
		_waiting[node.get_instance_id()] = weakref(node)

static func runtime_ready(runtime: GameRuntime) -> void:
	var pending := _waiting.values()
	_waiting.clear()
	for reference: WeakRef in pending:
		var node := reference.get_ref() as Node
		if is_instance_valid(node) and node.is_inside_tree():
			runtime.get_simulation_runtime().register_ticker(node)
