# This class is used to serialize a state chart state to a resource. It is intended 
# to make it easier to save and load state charts, as well as to transfer them
# over the network if needed. See also SerializedStateChartResource.
class_name SerializedStateChartState
extends Resource

@export var name: StringName = ""
@export var state_type: int = -1
@export var active: bool = false
@export var pending_transition_name: String = ""
@export var pending_transition_remaining_delay: float = 0.0
@export var pending_transition_initial_delay: float = 0.0
# Keep the Inspector/resource format and runtime element guard, but do not put a
# self-typed Array in the script's shared default values (Godot 4.6 retains the
# script through that default Array). Each instance owns its typed Array instead.
@export_custom(PROPERTY_HINT_TYPE_STRING, "24/17:SerializedStateChartState")
var children: Array = []:
	set(value):
		for child in value:
			if child != null and not child is SerializedStateChartState:
				push_error("State chart children must be SerializedStateChartState resources.")
				return
		children = Array(value, TYPE_OBJECT, &"Resource", get_script())

# Only used for history states
@export var history: SavedState = null

func _init() -> void:
	children = Array([], TYPE_OBJECT, &"Resource", get_script())


func _to_string() -> String:
	return """SerializedStateChartState(
		name: %s
		state_class: %s
		active: %s
		pending_transition_name: %s
		pending_transition_remaining_delay: %s
		pending_transition_initial_delay: %s
		children: %s
		history: %s
	)""" % [
		name,
		state_type,
		active,
		pending_transition_name,
		pending_transition_remaining_delay,
		pending_transition_initial_delay,
		JSON.stringify(children, "\t"),
		history.debug_string() if history != null else "null"
	]
