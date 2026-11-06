class_name GameplayFacts
extends RefCounted
## Scoped, post-commit facts. Not a command bus or an event-sourced state store.
signal committed(fact: Dictionary)
var sequence := 0
func publish(kind: String, source: String, data: Dictionary = {}) -> void:
	sequence+=1
	committed.emit({"sequence":sequence,"kind":kind,"source":source,"data":data.duplicate(true)})
