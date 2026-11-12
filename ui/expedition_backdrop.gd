class_name ExpeditionBackdrop
extends Control
## Original cartographic ornament. No actor, world state or gameplay random calls.
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 resized.connect(queue_redraw)
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),GameUIStyle.PANEL_BG_SOLID)
