class_name ButtonMotion
extends Node
var button: Button
var tween: Tween
static func install(target: Button) -> void:
	if target.has_node("ButtonMotion"): return
	var motion:=ButtonMotion.new(); motion.name="ButtonMotion"; motion.button=target
	target.add_child(motion)
func _ready() -> void:
	set_process(false)
	button.mouse_entered.connect(_highlight)
	button.mouse_exited.connect(_highlight)
	button.focus_entered.connect(_highlight)
	button.focus_exited.connect(_highlight)
	button.pressed.connect(_pressed)
func _highlight() -> void:
	if tween and tween.is_valid(): tween.kill()
	var on:=not button.disabled and (button.is_hovered() or button.has_focus())
	var color:=Color(1.08,1.08,1.08) if on else Color.WHITE
	if PresentationPreferences.value("reduced_motion"): button.self_modulate=color; return
	tween=create_tween(); tween.tween_property(button,"self_modulate",color,.09)
	set_process(true)
func _pressed() -> void:
	var director:=PresentationDirector.for_node(button)
	if director: director.emit_cue(&"ui_confirm",Vector2.ZERO)
func _process(_delta: float) -> void:
	if not tween or not tween.is_valid() or not tween.is_running(): set_process(false); return
	if PresentationPreferences.value("reduced_motion") and tween and tween.is_valid() and tween.is_running():
		tween.kill(); button.self_modulate=Color.WHITE; set_process(false)

