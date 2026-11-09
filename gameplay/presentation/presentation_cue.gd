class_name PresentationCue
extends Resource
## Reusable sensory definition. No animation methods, damage, costs or world commands.
@export var id: StringName
@export_enum("world","ui") var channel := "world"
@export var tint := Color("d2bd87")
@export_range(0.05,3.0) var duration := .5
@export_range(0.0,100.0) var radius := 28.0
@export_range(0,3) var priority := 0
@export var sound: AudioStream
@export_range(-40.0,0.0) var volume_db := -10.0
@export var frames: SpriteFrames
@export var animation: StringName=&"default"
@export var visual_scene: PackedScene
func valid() -> bool:
	return not id.is_empty() and channel in ["world","ui"] and Vector4(tint.r,tint.g,tint.b,tint.a).is_finite() and is_finite(duration) and duration>=.05 and duration<=3 and is_finite(radius) and radius>=0 and radius<=100 and priority>=0 and priority<=3 and is_finite(volume_db) and volume_db>=-40 and volume_db<=0 and (not frames or frames.has_animation(animation))

