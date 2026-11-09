class_name ActorAnimationProfile
extends Resource
## Shared immutable presentation definition. SpriteFrames and pose tracks stay native Godot resources.
const POSE_TRACKS: Array[String]=["Rig:position","Rig:rotation","Rig/Sockets/MainHand:position","Rig/Sockets/OffHand:position"]
const DIRECTIONS: Array[String]=["s","sw","w","nw","n","ne","e","se"]
@export var id: StringName
@export var title := ""
@export var equipment_free := true
@export var sprite_frames: SpriteFrames
@export var poses: AnimationLibrary
@export var clips: Array[ActorAnimationClip]=[]
@export var fallback: Dictionary={}
@export var body_scale:=Vector2(3,3)
@export var body_offset:=Vector2(0,-4)
@export var stride_distance := 64.0
func resolve(key: StringName) -> ActorAnimationClip:
	var seen: Dictionary={}
	var wanted:=key
	while not seen.has(wanted):
		seen[wanted]=true
		for clip in clips:
			if clip and clip.id==wanted: return clip
		if not fallback.has(str(wanted)): break
		wanted=StringName(str(fallback[str(wanted)]))
	for clip in clips:
		if clip and clip.id==&"idle": return clip
	return null
func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	if id.is_empty() or not sprite_frames or not poses: errors.append("Missing animation profile identity/frames/poses")
	if not body_scale.is_finite() or body_scale.x<=0 or body_scale.y<=0 or not body_offset.is_finite() or not is_finite(stride_distance) or stride_distance<=0: errors.append("Invalid animation scale/stride")
	var seen: Dictionary={}
	for clip in clips:
		if not clip or not clip.valid() or seen.has(clip.id): errors.append("Invalid/duplicate animation clip"); continue
		seen[clip.id]=true
		if poses and not poses.has_animation(clip.pose): errors.append("Missing pose: "+str(clip.pose))
		for direction in DIRECTIONS:
			var key:=StringName(str(clip.frames)+"_"+direction)
			if not sprite_frames or not sprite_frames.has_animation(key) or sprite_frames.get_frame_count(key)<1: errors.append("Missing directional frames: "+str(key))
	if not seen.has(&"idle"): errors.append("Missing idle fallback")
	for key in fallback:
		if not key is String or not fallback[key] is String: errors.append("Invalid animation fallback"); continue
		var visited: Dictionary={}; var next:=str(key)
		while fallback.has(next):
			if visited.has(next): errors.append("Cyclic animation fallback: "+str(key)); break
			visited[next]=true; next=str(fallback[next])
		if not seen.has(StringName(next)): errors.append("Unknown animation fallback: "+str(key))
	# Pose libraries cannot make calls, play other animations, or write gameplay paths.
	if poses:
		if not poses.has_animation("RESET"): errors.append("Missing RESET pose")
		else:
			var reset:=poses.get_animation("RESET"); var missing:=POSE_TRACKS.duplicate()
			for track in reset.get_track_count(): missing.erase(str(reset.track_get_path(track)))
			if not missing.is_empty(): errors.append("Incomplete RESET pose")
		for name in poses.get_animation_list():
			var animation:=poses.get_animation(name)
			if not is_finite(animation.length) or animation.length<=0: errors.append("Invalid pose duration")
			for track in animation.get_track_count():
				if animation.track_get_type(track)!=Animation.TYPE_VALUE or str(animation.track_get_path(track)) not in POSE_TRACKS: errors.append("Unsafe presentation track: "+str(name))
				if animation.track_get_type(track)==Animation.TYPE_VALUE:
					for key in animation.track_get_key_count(track):
						var value: Variant=animation.track_get_key_value(track,key)
						if str(animation.track_get_path(track)).ends_with(":rotation"):
							if not (value is int or value is float) or not is_finite(float(value)): errors.append("Invalid pose rotation")
						elif not value is Vector2 or not value.is_finite(): errors.append("Invalid pose position")
	return errors
static func direction_index(direction: Vector2) -> int:
	return posmod(roundi((direction.angle()-PI*.5)/(PI*.25)),8) if direction.length_squared()>.001 else 0
