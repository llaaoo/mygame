class_name SkillExecutionBatch
extends RefCounted
## Detached effects are activated only after every component accepts the action.
var nodes: Array[Dictionary] = []
var buffs: Array[Dictionary] = []
var casts: Array[Dictionary] = []

func abort() -> void:
	for entry in nodes:
		if is_instance_valid(entry.node):
			entry.node.free()
	nodes.clear()
	buffs.clear()
	casts.clear()
