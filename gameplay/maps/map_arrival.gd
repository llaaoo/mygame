@tool
class_name MapArrival
extends Marker2D
## Region-local stable name. Doors refer to this name instead of copied coordinates.
@export var id := "entry":
	set(value): id=value; queue_redraw()
@export var default_entry := false:
	set(value): default_entry=value; queue_redraw()
@export_range(0,2000,10) var minimum_enemy_distance := 0.0:
	set(value): minimum_enemy_distance=value; queue_redraw()
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	draw_circle(Vector2.ZERO,20,Color(.3,.9,.5,.25))
	draw_arc(Vector2.ZERO,20,0,TAU,32,Color.LIGHT_GREEN,2)
	if minimum_enemy_distance>0: draw_arc(Vector2.ZERO,minimum_enemy_distance,0,TAU,64,Color(.3,.9,.5,.2),1)
	draw_string(ThemeDB.fallback_font,Vector2(24,0),id+(" [entry]" if default_entry else ""),HORIZONTAL_ALIGNMENT_LEFT,260,15,Color.LIGHT_GREEN)
