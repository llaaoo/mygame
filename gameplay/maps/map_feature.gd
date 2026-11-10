@tool
class_name MapFeature
extends Node2D
## Position belongs to the scene. Compilation copies the Resource and sets pos.
@export var definition: Resource:
	set(value):
		definition=value
		queue_redraw()
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	draw_circle(Vector2.ZERO,12,Color(.3,.75,.85,.3))
	draw_arc(Vector2.ZERO,80,0,TAU,40,Color(.3,.75,.85,.25),1)
	draw_line(Vector2(-16,0),Vector2(16,0),Color.SKY_BLUE,2)
	draw_line(Vector2(0,-16),Vector2(0,16),Color.SKY_BLUE,2)
	if definition and "title" in definition:
		draw_string(GameUIStyle.font(),Vector2(-70,-22),str(definition.title),HORIZONTAL_ALIGNMENT_LEFT,240,14,Color.WHITE)
