class_name InteractionProvider
extends Node
## Present availability, then revalidate at the request boundary.
var options: Callable
var available: Callable
func get_actions(actor_id: String) -> Array[InteractionOption]:
	var result: Array[InteractionOption]=[]
	if available.is_valid() and not available.call(actor_id): return result
	if options.is_valid(): result.assign(options.call(actor_id))
	return result
func execute(actor_id: String,id: String) -> OperationResult:
	for option in get_actions(actor_id):
		if option.id==id: return option.execute()
	return OperationResult.reject("unavailable")
