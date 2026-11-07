class_name RuntimeRegistration
extends RefCounted
## Weak pending tickers join only the runtime whose scene contains them.

static var _waiting: Dictionary = {}


static func register_ticker(node: Node) -> void:
	if not node.is_inside_tree() or node.is_queued_for_deletion():
		return
	var runtime := runtime_for(node)
	if runtime and runtime.get_simulation_runtime():
		runtime.get_simulation_runtime().register_ticker(node)
		return

	var id := node.get_instance_id()
	if _waiting.has(id):
		return
	_waiting[id] = weakref(node)
	var discard := func() -> void:
		_waiting.erase(id)
	node.tree_exiting.connect(discard, CONNECT_ONE_SHOT)


static func runtime_ready(runtime: GameRuntime) -> void:
	for id in _waiting.keys():
		var reference: WeakRef = _waiting[id]
		var node := reference.get_ref() as Node
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
			_waiting.erase(id)
		elif _owns(runtime, node):
			runtime.get_simulation_runtime().register_ticker(node)
			_waiting.erase(id)


static func runtime_for(node: Node) -> GameRuntime:
	var runtime := GameRuntime.instance
	return runtime if is_instance_valid(runtime) and _owns(runtime, node) else null


static func combat_bus_for(node: Node) -> CombatEventBus:
	var runtime := runtime_for(node)
	return runtime.combat_event_bus if runtime else null


static func _owns(runtime: GameRuntime, node: Node) -> bool:
	var parent := runtime.get_parent()
	var scope: Node = parent if parent and not parent is Window else runtime
	return scope == node or scope.is_ancestor_of(node)
