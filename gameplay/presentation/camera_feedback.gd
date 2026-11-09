class_name CameraFeedback
extends Node
## Owns only a bounded Camera2D offset. Never zooms, delays input, moves actors or stops time.
var camera: Camera2D
var _base:=Vector2.ZERO
var _strength:=0.0
var _age:=0.0
func _ready() -> void:
	if camera: _base=camera.offset
func kick(amount: float) -> void:
	if not is_finite(amount) or not PresentationPreferences.value("camera_feedback") or PresentationPreferences.value("reduced_motion"): return
	_strength=minf(5,maxf(_strength,amount)); _age=0
func clear() -> void:
	_strength=0
	if is_instance_valid(camera): camera.offset=_base
func _process(delta: float) -> void:
	if not is_instance_valid(camera): return
	if not PresentationPreferences.value("camera_feedback") or PresentationPreferences.value("reduced_motion"): clear(); return
	_age+=delta; _strength=move_toward(_strength,0,delta*24)
	camera.offset=_base+Vector2(sin(_age*71),cos(_age*83)*.65)*_strength
func _exit_tree() -> void: clear()

