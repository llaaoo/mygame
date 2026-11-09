class_name ActorAnimationClip
extends Resource
## Presentation only: source phase markers remap onto authoritative gameplay phases.
@export var id: StringName
@export var frames: StringName
@export var pose: StringName=&"idle"
@export var footsteps: PackedFloat32Array=[]
@export var phase_markers:=Vector2(.4,.65)
func valid() -> bool:
	var previous := -1.0
	for marker in footsteps:
		if not is_finite(marker) or marker<0 or marker>=1 or marker<=previous: return false
		previous=marker
	return not id.is_empty() and not frames.is_empty() and not pose.is_empty() and is_finite(phase_markers.x) and is_finite(phase_markers.y) and phase_markers.x>0 and phase_markers.x<phase_markers.y and phase_markers.y<1
func sample(phase: String,progress: float) -> float:
	var value:=clampf(progress,0,1)
	match phase:
		"windup": return lerpf(0,phase_markers.x,value)
		"active": return lerpf(phase_markers.x,phase_markers.y,value)
		"recovery": return lerpf(phase_markers.y,1,value)
	return value
