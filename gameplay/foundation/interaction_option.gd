class_name InteractionOption
extends RefCounted
var id := ""
var title := ""
var reason := ""
var request: Callable
func execute() -> OperationResult:
	if not reason.is_empty() or not request.is_valid(): return OperationResult.reject(reason if not reason.is_empty() else "unavailable")
	return OperationResult.success() if request.call() else OperationResult.reject("conditions_changed")
