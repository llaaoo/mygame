class_name UIMotion
extends Node
## Alpha-only native Tween: layout, focus, mouse rectangles and close timing stay immediate.
var target: Control
var tween: Tween
static func enter(control: Control) -> void:
	var old:=control.get_node_or_null("UIMotion") as UIMotion
	if old: old.restart(); return
	var motion:=UIMotion.new(); motion.name="UIMotion"; motion.target=control
	control.add_child(motion)
func _ready() -> void: restart()
func restart() -> void:
	set_process(true)
	if tween and tween.is_valid(): tween.kill()
	if not is_instance_valid(target): return
	target.modulate.a=1 if PresentationPreferences.value("reduced_motion") else .72
	if target.modulate.a==1: set_process(false); return
	tween=create_tween(); tween.tween_property(target,"modulate:a",1.0,.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
func _process(_delta: float) -> void:
	if not tween or not tween.is_valid() or not tween.is_running(): set_process(false); return
	if PresentationPreferences.value("reduced_motion") and is_instance_valid(target):
		if tween and tween.is_valid(): tween.kill()
		target.modulate.a=1
		set_process(false)

