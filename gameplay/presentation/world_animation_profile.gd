class_name WorldAnimationProfile
extends Resource
## Native local property animation; domain and collision nodes are never track targets.
const TRACKS := ["Visual:position","Visual:scale","Visual:modulate"]
@export var poses: AnimationLibrary
@export var particle_color := Color("ffc071")
@export var visual_scene: PackedScene
static func defaults() -> WorldAnimationProfile: return load("res://content/presentation/world_object.tres") as WorldAnimationProfile
func validation_errors() -> PackedStringArray:
	var errors:=PackedStringArray()
	errors.append_array(PresentationScene.validation_errors(visual_scene))
	if not poses: errors.append("Missing world poses"); return errors
	for key in ["RESET","idle","active","depleted","complete"]:
		if not poses.has_animation(key): errors.append("Missing world pose: "+key)
	for id in poses.get_animation_list():
		var animation:=poses.get_animation(id)
		if not is_finite(animation.length) or animation.length<=0: errors.append("Invalid world pose duration")
		for track in animation.get_track_count():
			var path:=str(animation.track_get_path(track))
			if animation.track_get_type(track)!=Animation.TYPE_VALUE or path not in TRACKS: errors.append("Unsafe world pose track: "+path); continue
			for key in animation.track_get_key_count(track):
				var value: Variant=animation.track_get_key_value(track,key)
				if path=="Visual:modulate":
					if not value is Color or not Vector4(value.r,value.g,value.b,value.a).is_finite(): errors.append("Invalid world pose color")
				elif not value is Vector2 or not value.is_finite(): errors.append("Invalid world pose transform")
	if poses.has_animation("RESET"):
		var reset:=poses.get_animation("RESET")
		var found: Array[String]=[]
		for track in reset.get_track_count(): found.append(str(reset.track_get_path(track)))
		for path in TRACKS:
			if path not in found: errors.append("Incomplete world RESET: "+path)
	return errors

