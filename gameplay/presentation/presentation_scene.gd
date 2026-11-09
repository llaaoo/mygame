class_name PresentationScene
extends RefCounted
## Native visual-only prefabs; no scripts, collision, audio voices or gameplay callback tracks.
const TYPES := ["Node2D","CanvasGroup","Sprite2D","AnimatedSprite2D","CPUParticles2D","GPUParticles2D","AnimationPlayer","Marker2D","PointLight2D","Line2D","Polygon2D"]
class MotionPolicy extends Node:
	var speeds: Dictionary={}
	func _ready() -> void:
		for node in [get_parent()]+get_parent().find_children("*","",true,false):
			if node is CPUParticles2D or node is GPUParticles2D or node is AnimatedSprite2D or node is AnimationPlayer: speeds[node.get_instance_id()]=[weakref(node),node.get("speed_scale")]
		_process(0)
	func _process(_delta: float) -> void:
		for row in speeds.values():
			var node:=row[0].get_ref() as Node
			if is_instance_valid(node): node.set("speed_scale",float(row[1])*PresentationPreferences.motion_scale())
static func validation_errors(scene: PackedScene) -> PackedStringArray:
	var errors:=PackedStringArray()
	if not scene: return errors
	var state:=scene.get_state()
	if state.get_node_count()>128: errors.append("Visual prefab too large"); return errors
	for i in state.get_node_count():
		var type:=str(state.get_node_type(i))
		if state.get_node_instance(i): errors.append("Flatten visual prefab instances before registration")
		if type not in TYPES or i==0 and type=="AnimationPlayer": errors.append("Non-visual prefab node: "+type)
		var fixed:=false
		for property in state.get_node_property_count(i):
			var key:=str(state.get_node_property_name(i,property))
			var value: Variant=state.get_node_property_value(i,property)
			if key=="script" and value: errors.append("Visual prefab cannot own a script")
			if key=="root_node" and value not in [NodePath(".."),NodePath(".")]: errors.append("Visual animation root must stay inside its prefab")
			if key=="use_fixed_seed": fixed=bool(value)
			if key=="libraries" and value is Dictionary:
				for library: AnimationLibrary in value.values():
					for name in library.get_animation_list():
						var animation:=library.get_animation(name)
						for track in animation.get_track_count():
							var path:=str(animation.track_get_path(track))
							if animation.track_get_type(track) not in [Animation.TYPE_VALUE,Animation.TYPE_BEZIER] or ".." in path or path.begins_with("/"): errors.append("Unsafe visual prefab animation track")
		if type in ["CPUParticles2D","GPUParticles2D"] and not fixed: errors.append("Visual particles require their own fixed seed")
	return errors
static func attach(host: Node2D,scene: PackedScene) -> Node2D:
	if not scene or not validation_errors(scene).is_empty(): return null
	var visual:=scene.instantiate() as Node2D
	if not visual: return null
	host.add_child(visual)
	var policy:=MotionPolicy.new(); visual.add_child(policy)
	return visual

