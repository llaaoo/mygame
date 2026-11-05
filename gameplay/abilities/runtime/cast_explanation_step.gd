class_name CastExplanationStep
extends RefCounted
## Read-only presentation of a planned transformation; never executes or charges.
var kind: String
var source_id: String
var text: String
func _init(category: String, id: String, summary: String) -> void:
	kind = category
	source_id = id
	text = summary
