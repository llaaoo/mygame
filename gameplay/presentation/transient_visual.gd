class_name TransientVisual
extends Node2D
## Finite cosmetic instance. Optional native SpriteFrames can replace the sample geometry.
var definition: PresentationCue
var age := 0.0
var sprite: AnimatedSprite2D
var visual_override: PackedScene
var _custom: Node2D
func _ready() -> void:
	z_index=20
	if visual_override or definition.visual_scene:
		_custom=PresentationScene.attach(self,visual_override if visual_override else definition.visual_scene)
	if definition.frames:
		sprite=AnimatedSprite2D.new(); sprite.sprite_frames=definition.frames
		sprite.animation=definition.animation; sprite.modulate=definition.tint
		add_child(sprite); sprite.play()
func _process(delta: float) -> void:
	age+=maxf(0,delta)
	if age>=definition.duration: queue_free(); return
	if sprite: sprite.modulate.a=1-age/definition.duration
	if _custom: _custom.modulate.a=1-age/definition.duration
	queue_redraw()
func _draw() -> void:
	if sprite or _custom or definition.radius<=0: return
	var progress:=clampf(age/definition.duration,0,1)
	var motion:=PresentationPreferences.motion_scale()
	var r:=definition.radius*(.35+.65*progress*motion)
	var color:=Color(definition.tint,(1-progress)*.7)
	draw_arc(Vector2.ZERO,r,0,TAU,32,color,1.5,true)
	for i in range(6):
		var direction:=Vector2.from_angle(i*TAU/6)
		draw_line(direction*(r+3),direction*(r+7),color,2,true)

