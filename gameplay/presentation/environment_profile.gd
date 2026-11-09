class_name EnvironmentProfile
extends Resource
@export var id: StringName
@export var daylight := Color(1,1,.98)
@export var night := Color(.64,.70,.82)
@export var ambient_color := Color(.75,.78,.62,.18)
@export_range(0,32) var motes := 12
@export var wind := true
func valid() -> bool:
	return not id.is_empty() and motes>=0 and motes<=32 and Vector4(daylight.r,daylight.g,daylight.b,daylight.a).is_finite() and Vector4(night.r,night.g,night.b,night.a).is_finite() and Vector4(ambient_color.r,ambient_color.g,ambient_color.b,ambient_color.a).is_finite()

